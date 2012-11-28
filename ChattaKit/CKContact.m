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

- (void)setConnectionState:(ContactState)connectionState
{
    dispatch_sync(m_serialDispatchQueue, ^(void) {
        // update the contact list delegate that a contacts connection state
        // has been updated
        CKContactList *contactList = [CKContactList sharedInstance];
        if (contactList.delegate != nil) {
            [contactList.delegate contactConnectionStateUpdated:connectionState
                                                     forContact:self];
        }
        
        _connectionState = connectionState;
    });
}

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
                          andContactState:ContactStateIndeterminate];
}

- (CKContact *)initWithJabberIdentifier:(NSString *)jid 
                       andDisplayName:(NSString *)displayName 
                       andPhoneNumber:(NSString *)phoneNumber
{
    return [self initWithJabberIdentifier:jid 
                           andDisplayName:displayName 
                           andPhoneNumber:phoneNumber 
                          andContactState:ContactStateIndeterminate];
}

- (CKContact *)initWithJabberIdentifier:(NSString *)jid 
                       andDisplayName:(NSString *)displayName 
                       andPhoneNumber:(NSString *)phoneNumber
                      andContactState:(ContactState)contactState
{
    self = [super init];
    
    if(self != nil) {
        self.jabberIdentifier = jid;
        self.displayName = displayName;
        self.phoneNumber = phoneNumber;
        m_messages = [[NSMutableArray alloc] init];
        if (m_serialDispatchQueue == nil) {
            m_serialDispatchQueue = dispatch_queue_create("contact.serial.queue", NULL);
        }
        self.connectionState = contactState;
    }
    
    return self;
}

- (void)dealloc
{
    m_messages = nil;
    if (m_serialDispatchQueue) {
        dispatch_release(m_serialDispatchQueue);
    }
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

- (void)removeAllMessages
{
    dispatch_sync(m_serialDispatchQueue, ^(void) {
        if (m_messages == nil) {
            return;
        }
        [m_messages removeAllObjects];
    });
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
        self.connectionState      = ContactStateIndeterminate;
        [self replaceMessagesWith:[decoder decodeObjectForKey:@"messages"]];
    }
    return self;
}

#pragma mark Implementation for NSPasteboardWriting, NSPasteboardReading protocol

- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard
{
    return [self.displayName writableTypesForPasteboard:pasteboard];
}

- (id)pasteboardPropertyListForType:(NSString *)type
{
    return [self.displayName pasteboardPropertyListForType:type];
}

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard
{
    return [NSArray arrayWithObjects:(NSString *)kUTTypeText, nil];
}

- (id)initWithPasteboardPropertyList:(id)propertyList ofType:(NSString *)type
{
    self = [self init];
    if (self) {
        NSString *displayName = [[NSString alloc] initWithPasteboardPropertyList:propertyList ofType:type];
        
        CKContactList *contactList = [CKContactList sharedInstance];
        CKContact *contact = [contactList contactWithName:displayName];
        
        if (contact != nil) {
            self = contact;
        }
    }
    
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"displayName: %@, jid: %@, phoneNumber: %@, messages: %zu, "
            "unread messages: %zu, connectionState: %i", self.displayName, self.jabberIdentifier,
            self.phoneNumber, self.messages.count, self.unreadCount, self.connectionState];
}

@end