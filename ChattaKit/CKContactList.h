//
//  CKContactList.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CKContact;
@class CKMessage;

@protocol CKContactListDelegate <NSObject>
@optional
- (void)addedContact:(CKContact *)contact;
- (void)removedContact:(CKContact *)contact;
- (void)newMessage:(CKMessage *)message forContact:(CKContact *)contact;
- (void)contactConnectionStateUpdated:(ContactState)state forContact:(CKContact *)contact;
@end

@interface CKContactList : NSObject
{
    NSMutableArray *m_contactList;
    dispatch_queue_t m_serialDispatchQueue;
}

@property (atomic, strong) CKContact *me;
@property (assign, nonatomic) id <CKContactListDelegate> delegate;

+ (CKContactList *)sharedInstance;

- (id)init;

- (void)addContact:(CKContact *)contact;
- (void)removeContact:(CKContact *)contact;
- (void)removeAllContacts;
- (void)newMessage:(CKMessage *)message forContact:(CKContact *)contact;

- (NSArray *)allContacts;
- (NSArray *)allOnlineContacts;
- (void)replaceAllContacts:(NSArray *)contacts;

- (NSUInteger)count;

- (CKContact *)contactWithName:(NSString *)name;
- (CKContact *)contactWithJabberIdentifier:(NSString *)jid;
- (CKContact *)contactWithPhoneNumber:(NSString *)phoneNumber;
- (CKContact *)contactWithIndex:(NSInteger)index;
- (NSInteger)indexOfContact:(CKContact *)contact;

- (BOOL)containsContact:(CKContact *)contact;
- (void)swapContactsFrom:(NSInteger)sourceIndex to:(NSInteger)destinationIndex;

@end
