//
//  CKContact.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CKMessage;

@protocol CKContactDelegate <NSObject>
@optional
- (void)newMessage:(CKMessage *)message;
@end

typedef enum {
    kContactOnline,
    kContactOffline,
    kContactIndeterminate
} ContactConnectionState;



@interface CKContact : NSObject <NSCoding>
{
    NSMutableArray *m_messages;
    dispatch_queue_t m_serialDispatchQueue;
}

@property (atomic, strong) NSString *jabberIdentifier;
@property (atomic, strong) NSString *displayName;
@property (atomic, strong) NSString *phoneNumber;
@property (atomic) NSUInteger unreadCount;
@property (atomic) ContactConnectionState connectionState;
@property (strong, nonatomic, readonly) NSArray  *messages;

@property (nonatomic, assign) id <CKContactDelegate> delegate;


- (CKContact *)init;
- (CKContact *)initWithJabberIdentifier:(NSString *)jid
                       andDisplayName:(NSString *)displayName 
                       andPhoneNumber:(NSString *)phoneNumber;
- (CKContact *)initWithJabberIdentifier:(NSString *)jid
                       andDisplayName:(NSString *)displayName 
                       andPhoneNumber:(NSString *)phoneNumber
                      andContactState:(ContactConnectionState)contactState;

- (void)addMessage:(CKMessage *)message;
- (void)replaceMessagesWith:(NSArray *)messages;
- (void)updateConnectionState:(ContactConnectionState)connectionState;
- (BOOL)isEqualToContact:(CKContact *)object;

@end