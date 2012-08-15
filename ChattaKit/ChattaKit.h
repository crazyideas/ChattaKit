//
//  ChattaKit.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CKRoster.h"

// chatta constants
typedef enum {
    ChattaStateConnected = 0,
    ChattaStateDisconnected
} ChattaState;

// forward declaration of classes
@class CKTextMessageService;
@class CKInstantMessageService;
@class CKContactService;
@class CKContactList;
@class CKMessage;
@class CKContact;

@protocol ChattaKitDelegate <NSObject>
@optional
- (void)connectionStateNotification:(ChattaState)state;
@end

@interface ChattaKit : NSObject {    
    CKTextMessageService *textMessageService;
    CKInstantMessageService *instantMessageService;
    CKContactService *contactService;
    
    BOOL textServiceConnected;
    BOOL instantServiceConnected;
}

// properties
@property (nonatomic) NSTimeInterval checkInterval;
@property (nonatomic) ChattaState chattaState;
@property (assign, nonatomic) id <ChattaKitDelegate> delegate;

// init methods
- (id)init;
- (id)initWithMe:(CKContact *)me;

// login and logout methods
- (void)loginToServiceWith:(NSString *)username andPassword:(NSString *)password;
- (void)logoutOfService;

// send method
- (BOOL)sendMessage:(NSString *)message toContact:(CKContact *)contact;
- (void)requestContactStatus:(CKContact *)contact;

// request contact and roster information
- (CKRoster *)requestXmppRoster;

// contacts, new messages, and state management methods
- (void)connectionNotificationFrom:(id)sender withState:(BOOL)connected;

@end
