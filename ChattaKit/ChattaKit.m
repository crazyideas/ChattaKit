//
//  ChattaKit.m
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import "ChattaKit.h"
#import "CKTextMessageService.h"
#import "CKInstantMessageService.h"
#import "CKContactList.h"
#import "CKContact.h"
#import "CKMessage.h"
#import "CKTimer.h"

@implementation ChattaKit

- (id)init
{
    return [self initWithMe:nil];
}

- (id)initWithMe:(CKContact *)me
{
    self = [super init];
    if(self != nil) {
        self.textMessageService    = [[CKTextMessageService alloc] init];
        self.instantMessageService = [[CKInstantMessageService alloc] init];
        
        self.textMessageService.delegate    = self;
        self.instantMessageService.delegate = self;
        
        [CKContactList sharedInstance].me = me;
        
        self.chattaState = ChattaStateDisconnected;
        self.unreadCheckInterval = 30;
    }
    return self;
}

- (void)loginToServiceWith:(NSString *)username andPassword:(NSString *)password
{
    __block ChattaKit *block_self = self;
    
    // make sure username and password were passed in
    if (username == nil || password == nil) {
        return;
    }
    
    // if we are not currently connected, that means one login failed and we are trying to 
    // login again, which means we should try and logout of both services before trying again
    if (textServiceConnected == YES || instantServiceConnected == YES) {
        [self.textMessageService logoutOfService];
        [self.instantMessageService logoutOfService];
    }
    
    // setup params
    textServiceConnected    = NO;
    instantServiceConnected = NO;
    loginElapsedTime        = 0;
    
    // login to both accounts
    [self.textMessageService loginToServiceWithUsername:username password:password];
    [self.instantMessageService loginToServiceWithUsername:username password:password];
    
    // set a timeout to login
    self.loginCheckTimer = [[CKTimer alloc] initWithDispatchTime:0.0 interval:1.0 block:^(void) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            NSLog(@"[+] loginCheckTimer: %lu", loginElapsedTime);
            if (loginElapsedTime++ > 10) {
                CKDebug(@"[-] loginCheckTimer invalidating: login time elapsed");
                [block_self.loginCheckTimer invalidate];
                if (block_self.delegate != nil) {
                    [block_self.delegate connectionStateNotification:ChattaStateDisconnected];
                }
            }
        });
    }];
}

- (void)logoutOfService
{
    [self.loginCheckTimer invalidate];
    [self.textMessageService logoutOfService];
    [self.instantMessageService logoutOfService];
}

- (BOOL)sendMessage:(NSString *)message toContact:(CKContact *)contact
{
    // if contact is online, send the message via the instant messaging service
    if ([contact connectionState] == ContactStateOnline) {
        [self.instantMessageService sendMessage:message toContact:contact];
    } 
    // otherwise send via the text messaging service
    else {
        [self.textMessageService sendMessage:message toContact:contact];
    }
    
    return YES;
}

- (void)requestContactStatus:(CKContact *)contact
{
    [self.instantMessageService sendPresenceProbeTo:contact];
}

- (CKRoster *)requestXmppRoster
{
    return self.instantMessageService.xmppRoster;
}

#pragma mark Contact Management and Implementation of ChattaKitDelegate

- (void)connectionStateNotificationFrom:(id)sender connected:(BOOL)connected
{
    __block ChattaKit *block_self = self;
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        if ([sender isKindOfClass:[CKTextMessageService class]]) {
            textServiceConnected = connected;
        } else {
            instantServiceConnected = connected;
        }
        
        CKContactList *contactList = [CKContactList sharedInstance];
        
        // chatta connected
        if (block_self.chattaState == ChattaStateDisconnected) {
            if (textServiceConnected && instantServiceConnected) {
                self.chattaState = ChattaStateConnected;
                
                // notify delegate
                [block_self.loginCheckTimer invalidate];
                if (block_self.delegate != nil) {
                    [block_self.delegate connectionStateNotification:ChattaStateConnected];
                }
                
                // request presence information from all contacts to update status
                for (CKContact *contact in [contactList allContacts]) {
                    [self requestContactStatus:contact];
                }
            }
        }
        
        // chatta disconnected
        if (block_self.chattaState == ChattaStateConnected) {
            if (!textServiceConnected || !instantServiceConnected) {
                self.chattaState = ChattaStateDisconnected;
                
                [block_self.textMessageService logoutOfService];
                [block_self.instantMessageService logoutOfService];
                
                // notify delegate
                [block_self.loginCheckTimer invalidate];
                if (block_self.delegate != nil) {
                    [block_self.delegate connectionStateNotification:ChattaStateDisconnected];
                }
                
                // update all contacts to indeterminate since we are
                // not longer connected to either service
                for (CKContact *contact in [contactList allContacts]) {
                    contact.connectionState = ContactStateIndeterminate;
                }
            }
        }
    });
}

@end
