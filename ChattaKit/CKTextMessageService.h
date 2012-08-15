//
//  CKTextMessageService.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ChattaKit.h"
#import "CKContact.h"
#import "CKTimer.h"

@interface CKTextMessageService : NSObject
{
    dispatch_queue_t dispatch_queue;
    CKTimer *fetchUnreadMessagesTimer;
}

@property (nonatomic, weak) ChattaKit *chattaKit;
@property (nonatomic, strong) NSString *textAuthToken;
@property (nonatomic, strong) NSString *contactsAuthToken;
@property (nonatomic, strong) NSString *accountTimezone;
@property (nonatomic, strong) NSString *accountSendKey;
@property (nonatomic, strong) NSString *accountRefreshKey;

- (id)init;

- (void)loginToServiceWithUsername:(NSString *)username password:(NSString *)password;
- (void)logoutOfService;

- (void)sendMessage:(NSString *)message toContact:(CKContact *)contact;

@end
