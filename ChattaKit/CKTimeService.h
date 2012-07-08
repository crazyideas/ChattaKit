//
//  CKTimeService.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CKTimeService : NSObject
{
    NSTimeZone *serviceTimeZone;
    NSTimeZone *systemTimeZone;
}

+ (CKTimeService *)sharedInstance;

- (void)setServiceTimeZone:(NSString *)timezone;
- (NSDate *)dateInSystemTimeZone:(NSDate *)t;
- (NSDate *)dateInServiceTimeZone:(NSDate *)t;

@end