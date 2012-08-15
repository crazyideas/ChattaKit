//
//  CKConstants.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CKConstants

// text message service constants
extern NSString * const DIV_ID_NODE_CLASS;
extern NSString * const DIV_MESSAGE_CLASS;
extern NSString * const SPAN_MESSAGE_TEXT_CLASS;
extern NSString * const SPAN_MESSAGE_FROM_CLASS;
extern NSString * const SPAN_MESSAGE_TIME_CLASS;

extern NSString * const SERVICE_CLIENT_LOGIN_URL;
extern NSString * const SERVICE_SETTINGS_URL;
extern NSString * const SERVICE_MAIN_PAGE_URL;
extern NSString * const SERVICE_XPC_URL;
extern NSString * const SERVICE_MARK_MESSAGE_URL;
extern NSString * const SERVICE_UNREAD_INBOX_URL;
extern NSString * const SERVICE_SEND_URL;

extern NSString * const SERVICE_CONTACTS_REQ_URL;

+ (NSArray *)serviceErrorCodes;

// instant message service constants
typedef enum {
    kStateNotConnected,
    kStateWaitingForStream,
    kStateWaitingForFeatures,
    kStateWaitingForAuth,
    kStateWaitingForSessionStream,
    kStateWaitingForFeaturesBindSession,
    kStateWaitingForInfoQueryBind,
    kStateConnected,
    kStateInvalidState
} ServiceStreamState;

typedef enum {
    kStreamStream,
    kStreamFeatures,
    kStreamError,
    kStreamStreamClose,
    kStanzaAuth,
    kStanzaSuccess,
    kStanzaFailure,
    kStanzaInfoQuery,
    kStanzaPresence,
    kStanzaMessage,
    kInvalidElementType
} XMLElementType;

@end

