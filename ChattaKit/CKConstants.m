//
//  CKConstants.m
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import "CKConstants.h"

@implementation CKConstants

NSString * const DIV_ID_NODE_CLASS       = @"goog-flat-button gc-message gc-message-unread gc-message-sms";
NSString * const DIV_MESSAGE_CLASS       = @"gc-message-sms-row";
NSString * const SPAN_MESSAGE_TEXT_CLASS = @"gc-message-sms-text";
NSString * const SPAN_MESSAGE_FROM_CLASS = @"gc-message-sms-from";
NSString * const SPAN_MESSAGE_TIME_CLASS = @"gc-message-sms-time";

NSString * const SERVICE_CLIENT_LOGIN_URL = @"https://www.google.com/accounts/ClientLogin";
NSString * const SERVICE_SETTINGS_URL     = @"https://www.google.com/voice/settings/tab/settings";
NSString * const SERVICE_MAIN_PAGE_URL    = @"https://www.google.com/voice";
NSString * const SERVICE_XPC_URL          = @"https://www.google.com/voice/xpc/";
NSString * const SERVICE_MARK_MESSAGE_URL = @"https://www.google.com/voice/inbox/mark/";
NSString * const SERVICE_UNREAD_INBOX_URL = @"https://www.google.com/voice/inbox/recent/unread/sms/";
NSString * const SERVICE_SEND_URL         = @"https://www.google.com/voice/sms/send/";

+ (NSArray *)serviceErrorCodes
{
    static NSArray *staticServiceErrorCodes;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        staticServiceErrorCodes = [NSArray arrayWithObjects:@"BadAuthentication",
                                                            @"NotVerified",
                                                            @"TermsNotAgreed",
                                                            @"CaptchaRequired",
                                                            @"Unknown",
                                                            @"AccountDeleted",
                                                            @"AccountDisabled",
                                                            @"ServiceDisabled",
                                                            @"ServiceUnavailable", 
                                                            nil];
    });
    
    return staticServiceErrorCodes;
}

@end