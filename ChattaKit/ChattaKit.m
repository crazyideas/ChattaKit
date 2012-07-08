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

@implementation ChattaKit

@synthesize chattaState   = _chattaState;
@synthesize checkInterval = _checkInterval;
@synthesize delegate      = _delegate;

- (id)init
{
    return [self initWithMe:nil];
}

- (id)initWithMe:(CKContact *)me
{
    self = [super init];
    if(self != nil) {
        textMessageService    = [[CKTextMessageService alloc] init];
        instantMessageService = [[CKInstantMessageService alloc] init];
        
        textMessageService.chattaKit = self;
        instantMessageService.chattaKit = self;
        
        [CKContactList sharedInstance].me = me;
        
        self.checkInterval = 30;
    }
    return self;
}

- (void)loginToServiceWith:(NSString *)username andPassword:(NSString *)password
{
    // make sure username and password were passed in
    if (username == nil || password == nil) {
        return;
    }
    
    // if we are not currently connected, that means one login failed and we are trying to 
    // login again, which means we should try and logout of both services before trying again
    if (textServiceConnected == YES || instantServiceConnected == YES) {
        [textMessageService logoutOfService];
        [instantMessageService logoutOfService];
    }
    
    // login to both accounts
    [textMessageService loginToServiceWithUsername:username password:password];
    [instantMessageService loginToServiceWithUsername:username password:password];
}

- (void)logoutOfService
{
    //teardown connections
    [textMessageService logoutOfService];
    [instantMessageService logoutOfService];
}

- (BOOL)sendMessage:(NSString *)message toContact:(CKContact *)contact
{
    // if contact is online, send the message via the instant messaging service
    if ([contact connectionState] == kContactOnline) {
        [instantMessageService sendMessage:message toContact:contact];
    } 
    // otherwise send via the text messaging service
    else {
        [textMessageService sendMessage:message toContact:contact];
    }
    
    return YES;
}

- (void)requestContactStatus:(CKContact *)contact
{
    [instantMessageService sendPresenceProbeTo:contact];
}

#pragma mark Contact Management and Implementation of ChattaKitDelegate

- (void)connectionNotificationFrom:(id)sender withState:(BOOL)connected
{    
    if ([sender isKindOfClass:[CKTextMessageService class]]) {
        textServiceConnected = connected;
    } else { 
        instantServiceConnected = connected;
    }
    
    CKContactList *contactList = [CKContactList sharedInstance];
    
    // if we have connected to both services, notify delegate that we are connected
    if (textServiceConnected && instantServiceConnected) {
        self.chattaState = ChattaStateConnected;
        [self.delegate connectionStateNotification:self.chattaState];
        
        // update all contacts to offline, then let the asynchronous presence
        // notifications come in to reflect if they are online or not
        for (CKContact *contact in [contactList allContacts]) {
            [contact updateConnectionState:kContactOffline];
        }
    }
    // if either service gets disconnected, inform delegate that we are not longer connected
    else {
        // if we are already disconnected, no need to return another disconnect notification
        if (self.chattaState == ChattaStateDisconnected) {
            return;
        }
        
        if (!textServiceConnected || !instantServiceConnected) {
            self.chattaState = ChattaStateDisconnected;
            
            // update delegate
            [self.delegate connectionStateNotification:self.chattaState];
            
            // update all contacts to indeterminate since we are
            // not longer connected to either service  
            for (CKContact *contact in [contactList allContacts]) {
                [contact updateConnectionState:kContactIndeterminate];
            }
        }
    }
}

@end
