//
//  CKTimeService.m
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import "CKTimeService.h"

@implementation CKTimeService

+ (CKTimeService *)sharedInstance
{
    static dispatch_once_t onceToken;
    static CKTimeService *staticSharedInstance;
    
    dispatch_once(&onceToken, ^{
        staticSharedInstance = [[CKTimeService alloc] init];
    });
    
    return staticSharedInstance;
}

- (void)setServiceTimeZone:(NSString *)t
{
    serviceTimeZone = [[NSTimeZone alloc] initWithName:t];
    systemTimeZone  = [NSTimeZone systemTimeZone];
}

- (NSDate *)dateInSystemTimeZone:(NSDate *)t
{    
    NSInteger serviceTzOffset = [serviceTimeZone secondsFromGMT];
    NSInteger systemTzOffset  = [systemTimeZone secondsFromGMT];
    NSInteger tzOffset        = systemTzOffset - serviceTzOffset;
    
    return [t dateByAddingTimeInterval:tzOffset];
}

- (NSDate *)dateInServiceTimeZone:(NSDate *)t
{
    NSInteger serviceTzOffset = [serviceTimeZone secondsFromGMT];
    NSInteger systemTzOffset  = [systemTimeZone secondsFromGMT];
    NSInteger tzOffset        = serviceTzOffset - systemTzOffset;
    
    return [t dateByAddingTimeInterval:tzOffset];
}

@end
