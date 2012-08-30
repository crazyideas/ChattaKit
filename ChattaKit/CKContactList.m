//
//  CKContactList.m
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import "CKContactList.h"
#import "CKContact.h"

@implementation CKContactList

+ (CKContactList *)sharedInstance
{
    static dispatch_once_t onceToken;
    static CKContactList *staticSharedInstance;
    
    dispatch_once(&onceToken, ^{
        staticSharedInstance = [[CKContactList alloc] init];
    });
    
    return staticSharedInstance;
}


- (id)init
{
    self = [super init];
    if(self != nil) {
        m_contactList = [[NSMutableArray alloc] init];
        m_serialDispatchQueue = dispatch_queue_create("contactlist.serial.queue", NULL);
    }
    return self;
}

- (void)addContact:(CKContact *)contact
{
    dispatch_sync(m_serialDispatchQueue, ^(void) {
        [m_contactList addObject:contact];
    });
    
    if (self.delegate != nil) {
        [self.delegate addedContact:contact];
    }
}

- (void)removeContact:(CKContact *)contact
{
    dispatch_sync(m_serialDispatchQueue, ^(void) { 
        [m_contactList removeObject:contact];
    });
    
    if (self.delegate != nil) {
        [self.delegate removedContact:contact];
    }
}

- (void)removeAllContacts
{
    dispatch_sync(m_serialDispatchQueue, ^(void) {
        [m_contactList removeAllObjects];
    });
}

- (void)newMessage:(CKMessage *)message forContact:(CKContact *)contact
{
    [contact addMessage:message];
    
    if (self.delegate != nil) {
        [self.delegate newMessage:message forContact:contact];
    }
}

- (NSArray *)allContacts
{
    __block NSArray *contactListCopy;
    
    dispatch_sync(m_serialDispatchQueue, ^(void) { 
        contactListCopy = [m_contactList copy];
    });
    
    return contactListCopy;
}

- (NSArray *)allOnlineContacts
{
    __block NSMutableArray *onlineArray = [[NSMutableArray alloc] init];
    
    dispatch_sync(m_serialDispatchQueue, ^(void) { 
        for (CKContact *contact in m_contactList) {
            if (contact.connectionState == ContactStateOnline) {
                [onlineArray addObject:contact];
            }
        }
    });
    
    return [onlineArray copy];
}

- (void)replaceAllContacts:(NSArray *)contacts
{
    dispatch_sync(m_serialDispatchQueue, ^(void) {
        m_contactList = [[NSMutableArray alloc] initWithArray:contacts];
    });
}

- (NSUInteger)count
{
    __block NSUInteger numContacts;
    
    dispatch_sync(m_serialDispatchQueue, ^(void) { 
        numContacts = [m_contactList count];
    });
    
    return numContacts;
}

- (CKContact *)contactWithName:(NSString *)name
{
    __block CKContact *foundContact;
    
    if (name == nil) {
        return nil;
    }
    
    dispatch_sync(m_serialDispatchQueue, ^(void) { 
        for (CKContact *contact in m_contactList) {
            if ([contact.displayName isEqualToString:name]) {
                foundContact = contact;
                break;
            }
        }
    });
    
    return foundContact;
}

- (CKContact *)contactWithJabberIdentifier:(NSString *)jid
{
    __block CKContact *foundContact;
    
    if (jid == nil) {
        return nil;
    }
    
    dispatch_sync(m_serialDispatchQueue, ^(void) { 
        for (CKContact *contact in m_contactList) {
            if ([contact.jabberIdentifier isEqualToString:jid]) {
                foundContact = contact;
                break;
            }
        }
    });
    
    return foundContact;
}

- (CKContact *)contactWithPhoneNumber:(NSString *)phoneNumber
{
    __block CKContact *foundContact;
    
    if (phoneNumber == nil) {
        return nil;
    }
    
    dispatch_sync(m_serialDispatchQueue, ^(void) { 
        for (CKContact *contact in m_contactList) {
            if ([contact.phoneNumber isEqualToString:phoneNumber]) {
                foundContact = contact;
                break;
            }
        }
    });
    
    return foundContact;
}

- (CKContact *)contactWithIndex:(NSInteger)index
{
    __block CKContact *foundContact;
    
    if (index < 0) {
        return nil;
    }
    
    dispatch_sync(m_serialDispatchQueue, ^(void) {
        if (index > m_contactList.count) {
            foundContact = nil;
        } else {
            foundContact = [m_contactList objectAtIndex:index];
        }
    });
    
    return foundContact;
}

- (NSInteger)indexOfContact:(CKContact *)contact
{
    __block NSInteger contactIndex = -1;

    if (contact == nil) {
        return contactIndex;
    }
    
    dispatch_sync(m_serialDispatchQueue, ^(void) {
        [[self allContacts] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            CKContact *blkContact = obj;
            if ([blkContact isEqualToContact:contact]) {
                contactIndex = idx;
                *stop = YES;
            }
        }];
    });
    
    return contactIndex;
}

- (BOOL)containsContact:(CKContact *)contact
{
    __block BOOL foundContact;
    
    if (contact == nil) {
        return NO;
    }
    
    dispatch_sync(m_serialDispatchQueue, ^(void) { 
        foundContact = [m_contactList containsObject:contact];
    });
    
    return foundContact;
}

#pragma mark - Debugging

- (NSString *)description
{
    return [NSString stringWithFormat:@"Me: %@, Items in Contact List: %li", self.me, [self count]];
}


@end
