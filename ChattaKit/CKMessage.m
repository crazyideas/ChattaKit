//
//  CKMessage.m
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import "CKMessage.h"
#import "CKContact.h"

@implementation CKMessage

- (id)initWithContact:(CKContact *)contact
{
    return [self initWithContact:contact timestamp:nil messageText:nil];
}

- (id)initWithContact:(CKContact *)contact 
            timestamp:(NSDate *)timestamp 
          messageText:(NSString *)message
{
    self = [super init];
    if(self != nil) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"hh:mm a"];
        
        self.contact = contact;
        self.timestampString = (timestamp != nil) ? [formatter stringFromDate:timestamp] : nil;
        self.timestamp = timestamp;
        self.text = message;
    }
    return self;
}

#pragma mark Overriding isEqual* and hash for object comparison

- (BOOL)isEqual:(id)object
{
    if (object == nil || ![object isKindOfClass:self.class]) {
        return NO;
    }
    if (object == self) {
        return YES;
    }
    return [self isEqualToMessage:object];
}

- (BOOL)isEqualToMessage:(CKMessage *)object
{
    if (![self.timestampString isEqualToString:object.timestampString] || 
        ![self.text isEqualToString:object.text] ||
        ![self.contact.displayName isEqualToString:object.contact.displayName]) {
        return NO;
    }
    return YES;
}

- (NSUInteger)hash
{
    return [[NSString stringWithFormat:@"%@%@%@", 
             self.contact.displayName, self.timestampString, self.text] hash];
}

#pragma mark Implementation for NSCoder protocol

-(void) encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.contact forKey:@"contact"];
    [coder encodeObject:self.text forKey:@"messageText"];
    [coder encodeObject:self.timestampString forKey:@"timestampString"];
    [coder encodeObject:self.timestamp forKey:@"timestamp"];
}

-(id) initWithCoder:(NSCoder *)decoder
{
    if (self = [super init]) {
        self.contact         = [decoder decodeObjectForKey:@"contact"];
        self.text            = [decoder decodeObjectForKey:@"messageText"];
        self.timestampString = [decoder decodeObjectForKey:@"timestampString"];
        self.timestamp       = [decoder decodeObjectForKey:@"timestamp"];
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:
            @"contactName: %@, timestamp: %@, timestampString: %@, messageText: %@", 
            self.contact.displayName, self.timestamp, self.timestampString, self.text];
}
 

@end