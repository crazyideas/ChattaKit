//
//  ChattaKit.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CKTextMessageService.h"
#import "CKInstantMessageService.h"

@class CKRoster;
@class CKContactList;
@class CKMessage;
@class CKContact;
@class CKTimer;

@protocol CKTextMessageDelegate;
@protocol CKInstantMessageDelegate;

@protocol ChattaKitDelegate <NSObject>
@optional
- (void)connectionStateNotification:(ChattaState)state;
@end

@interface ChattaKit : NSObject <CKTextMessageDelegate, CKInstantMessageDelegate>
{
    BOOL textServiceConnected;
    BOOL instantServiceConnected;
    
    NSUInteger loginElapsedTime;
}

@property (nonatomic, strong) CKTextMessageService *textMessageService;
@property (nonatomic, strong) CKInstantMessageService *instantMessageService;
@property (nonatomic, strong) CKTimer *loginCheckTimer;
@property (nonatomic) NSTimeInterval unreadCheckInterval;
@property (nonatomic) ChattaState chattaState;
@property (assign, nonatomic) id <ChattaKitDelegate> delegate;

- (id)init;
- (id)initWithMe:(CKContact *)me;

- (void)loginToServiceWith:(NSString *)username andPassword:(NSString *)password;
- (void)logoutOfService;

- (BOOL)sendMessage:(NSString *)message toContact:(CKContact *)contact;
- (void)requestContactStatus:(CKContact *)contact;
- (CKRoster *)requestXmppRoster;

@end
