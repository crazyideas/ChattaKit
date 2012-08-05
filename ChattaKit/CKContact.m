//
//  CKContact.m
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import "CKContactList.h"
#import "CKContact.h"
#import "CKMessage.h"

@implementation CKContact

@synthesize jabberIdentifier = _jabberIdentifier;
@synthesize displayName      = _displayName;
@synthesize phoneNumber      = _phoneNumber;
@synthesize connectionState  = _connectionState;
@synthesize messages         = _messages;
@synthesize unreadCount      = _unreadCount;

- (NSArray *)messages
{
    __block NSArray *returnMessages;
    
    if (m_messages == nil) {
        returnMessages = nil;
    }
    
    dispatch_sync(m_serialDispatchQueue, ^(void) {
        returnMessages = [m_messages copy];
    });
    
    return returnMessages;
}

- (CKContact *)init
{
    return [self initWithJabberIdentifier:nil 
                           andDisplayName:nil 
                           andPhoneNumber:nil 
                          andContactState:kContactIndeterminate];
}

- (CKContact *)initWithJabberIdentifier:(NSString *)jid 
                       andDisplayName:(NSString *)displayName 
                       andPhoneNumber:(NSString *)phoneNumber
{
    return [self initWithJabberIdentifier:jid 
                           andDisplayName:displayName 
                           andPhoneNumber:phoneNumber 
                          andContactState:kContactIndeterminate];
}

- (CKContact *)initWithJabberIdentifier:(NSString *)jid 
                       andDisplayName:(NSString *)displayName 
                       andPhoneNumber:(NSString *)phoneNumber
                      andContactState:(ContactConnectionState)contactState
{
    self = [super init];
    
    if(self != nil) {
        self.jabberIdentifier = jid;
        self.displayName = displayName;
        self.phoneNumber = phoneNumber;
        self.connectionState = contactState;
        m_messages = [[NSMutableArray alloc] init];
        m_serialDispatchQueue = dispatch_queue_create("contact.serial.queue", NULL);
    }
    
    return self;
}

- (void)addMessage:(CKMessage *)message
{
    dispatch_sync(m_serialDispatchQueue, ^(void) {
        [m_messages addObject:message];
    });
}

- (void)replaceMessagesWith:(NSArray *)messages
{
    dispatch_sync(m_serialDispatchQueue, ^(void) {
        if (m_messages == nil) {
            m_messages = [[NSMutableArray alloc] init];
        }
        [m_messages removeAllObjects];
        [m_messages addObjectsFromArray:messages];
    });
}

- (void)updateConnectionState:(ContactConnectionState)connectionState
{
    self.connectionState = connectionState;
    
    // update the contact list delegate that a contacts connection state has been updated
    CKContactList *contactList = [CKContactList sharedInstance];
    if (contactList.delegate != nil) {
        [contactList.delegate contactConnectionStateUpdated:connectionState 
                                                 forContact:self];
    }
}

- (BOOL)isEqualToContact:(CKContact *)object
{
    if (object == self) {
        return YES;
    }
    if (![self.jabberIdentifier isEqualToString:object.jabberIdentifier] || 
        ![self.displayName isEqualToString:object.displayName] ||
        ![self.phoneNumber isEqualToString:object.phoneNumber]) {
        return NO;
    }
    return YES;
}

#pragma mark Implementation for NSCoder protocol

-(void) encodeWithCoder:(NSCoder *)coder
{    
    [coder encodeObject:self.jabberIdentifier forKey:@"jabberIdentifier"];
    [coder encodeObject:self.displayName forKey:@"displayName"];
    [coder encodeObject:self.phoneNumber forKey:@"phoneNumber"];
    [coder encodeInteger:self.unreadCount forKey:@"unreadCount"];
    [coder encodeInteger:self.connectionState forKey:@"connectionState"];
    [coder encodeObject:self.messages forKey:@"messages"];
}

-(id) initWithCoder:(NSCoder *)decoder
{
    if (self = [super init]) {
        m_serialDispatchQueue = dispatch_queue_create("contact.serial.queue", NULL);
        self.jabberIdentifier     = [decoder decodeObjectForKey:@"jabberIdentifier"];
        self.displayName          = [decoder decodeObjectForKey:@"displayName"];
        self.phoneNumber          = [decoder decodeObjectForKey:@"phoneNumber"];
        self.unreadCount          = [decoder decodeIntegerForKey:@"unreadCount"];
        self.connectionState      = [decoder decodeIntegerForKey:@"connectionState"];
        [self replaceMessagesWith:[decoder decodeObjectForKey:@"messages"]];
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"jid: %@, displayName: %@, phoneNumber: %@, messages: %zu", 
            self.jabberIdentifier, self.displayName, self.phoneNumber, self.messages.count];
}

@end