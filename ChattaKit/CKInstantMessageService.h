//
//  CKInstantMessageService.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CKContact;
@class CKRoster;
@class CKRosterItem;

@protocol CKInstantMessageDelegate <NSObject>
@optional
- (void)connectionStateNotificationFrom:(id)sender connected:(BOOL)connected;
@end


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

@property (strong, nonatomic) NSString *username;
@property (strong, nonatomic) NSString *password;
@property (strong, nonatomic) NSString *fullJabberIdentifier;
@property (strong, nonatomic) NSString *infoQueryIdentifier;
@property (strong, nonatomic) NSString *streamNamespace;
@property (strong, nonatomic) CKRoster *xmppRoster;
@property (nonatomic, assign) id <CKInstantMessageDelegate> delegate;
@property (nonatomic) ServiceStreamState streamState;
@property (nonatomic) BOOL signedIn;


- (id)init;

- (void)loginToServiceWithUsername:(NSString *)username password:(NSString *)password;
- (void)logoutOfService;

- (void)sendMessage:(NSString *)message toContact:(CKContact *)contact;
- (void)sendPresenceProbeTo:(CKContact *)contact;

@end
