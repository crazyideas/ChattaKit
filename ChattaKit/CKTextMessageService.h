//
//  CKTextMessageService.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CKContact;
@class CKTimer;

@protocol CKTextMessageDelegate <NSObject>
@optional
- (void)connectionStateNotificationFrom:(id)sender connected:(BOOL)connected;
@end


@interface CKTextMessageService : NSObject
{
    dispatch_queue_t dispatch_queue;
}

@property (nonatomic, strong) NSString *textAuthToken;
@property (nonatomic, strong) NSString *contactsAuthToken;
@property (nonatomic, strong) NSString *accountTimezone;
@property (nonatomic, strong) NSString *accountSendKey;
@property (nonatomic, strong) NSString *accountRefreshKey;
@property (nonatomic, strong) CKTimer *fetchUnreadMessagesTimer;
@property (nonatomic, assign) id <CKTextMessageDelegate> delegate;

- (id)init;

- (void)loginToServiceWithUsername:(NSString *)username password:(NSString *)password;
- (void)logoutOfService;

- (void)sendMessage:(NSString *)message toContact:(CKContact *)contact;

@end
