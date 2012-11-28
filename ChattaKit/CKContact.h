//
//  CKContact.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CKMessage;

@interface CKContact : NSObject <NSCoding, NSPasteboardWriting, NSPasteboardReading>
{
    NSMutableArray *m_messages;
    dispatch_queue_t m_serialDispatchQueue;
}

@property (atomic, strong) NSString *jabberIdentifier;
@property (atomic, strong) NSString *displayName;
@property (atomic, strong) NSString *phoneNumber;
@property (nonatomic) ContactState connectionState;
@property (atomic) NSUInteger unreadCount;
@property (strong, nonatomic, readonly) NSArray *messages;

- (CKContact *)init;
- (CKContact *)initWithJabberIdentifier:(NSString *)jid
                       andDisplayName:(NSString *)displayName 
                       andPhoneNumber:(NSString *)phoneNumber;
- (CKContact *)initWithJabberIdentifier:(NSString *)jid
                       andDisplayName:(NSString *)displayName 
                       andPhoneNumber:(NSString *)phoneNumber
                      andContactState:(ContactState)contactState;

- (void)addMessage:(CKMessage *)message;
- (void)replaceMessagesWith:(NSArray *)messages;
- (void)removeAllMessages;
- (BOOL)isEqualToContact:(CKContact *)object;

@end
