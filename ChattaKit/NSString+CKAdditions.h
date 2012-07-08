//
//  NSString+CKAdditions.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (CKAdditions)

// instance methods
- (BOOL)containsString:(NSString *)string;
- (NSString *)base64EncodedString;
- (NSString *)base64DecodedString;
- (NSString *) stringByRemovingWhitespaceNewlineChars;

// static methods
+ (NSString *)randomStringWithLength:(NSUInteger)length;
+ (NSString *)stringByStrippingTag:(NSString *)name fromXMLString:(NSString *)string;
+ (NSString *)stringWithUrlEncoding:(NSString *)string;

@end
