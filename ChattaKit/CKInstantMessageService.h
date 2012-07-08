//
//  CKInstantMessageService.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CKContact.h"
#import "ChattaKit.h"

@interface CKInstantMessageService : NSObject <NSStreamDelegate, NSXMLParserDelegate>
{
    // stream and xml processing ivars
    NSInputStream *inputStream;
    NSOutputStream *outputStream;
    NSXMLParser *xmlParser;
    
    // dispatch queue for xml parser
    dispatch_queue_t dispatch_queue;
    
    // stanza processing ivars 
    NSMutableString *receivedElement;
    XMLElementType currentElement;
    BOOL processingElement;
    
    // server ping timer
    NSTimer *serverPingTimer;
}

// properties
@property (strong, nonatomic) ChattaKit *chattaKit;
@property (strong, nonatomic) NSString *username;
@property (strong, nonatomic) NSString *password;
@property (strong, nonatomic) NSString *fullJabberIdentifier;
@property (strong, nonatomic) NSString *infoQueryIdentifier;
@property (strong, nonatomic) NSString *streamNamespace;
@property (nonatomic) BOOL signedIn;
@property (nonatomic) ServiceStreamState streamState;

// methods
- (id)init;

- (void)loginToServiceWithUsername:(NSString *)username password:(NSString *)password;
- (void)logoutOfService;

- (void)sendMessage:(NSString *)message toContact:(CKContact *)contact;
- (void)sendPresenceProbeTo:(CKContact *)contact;

@end