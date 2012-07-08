//
//  CKMessage.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CKContact;

@interface CKMessage : NSObject <NSCoding>

@property (nonatomic, weak) CKContact *contact;
@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) NSString *timestampString;
@property (nonatomic, strong) NSDate   *timestamp;

- (id)initWithContact:(CKContact *)contact;
- (id)initWithContact:(CKContact *)contact 
            timestamp:(NSDate *)timestamp 
          messageText:(NSString *)message;

- (BOOL)isEqualToMessage:(CKMessage *)object;

@end