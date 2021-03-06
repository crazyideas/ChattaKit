//
//  CKInstantMessageService.m
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import "CKInstantMessageService.h"
#import "NSString+CKAdditions.h"
#import "CKStanzaLibrary.h"
#import "CKContactList.h"
#import "CKTimeService.h"
#import "CKXMLDocument.h"
#import "CKMessage.h"
#import "CKContact.h"
#import "CKRoster.h"
#import "CKRosterItem.h"
#import "CKContactMerger.h"

@implementation CKInstantMessageService

- (id)init
{
    self = [super init];
    if(self != nil) {
        // dispatch queue for nsxmlparser hooked up to nsinputstream
        dispatch_queue = dispatch_queue_create("nsxmlparser.queue", NULL);
        
        // alloc/init the elements for nsxmlparser
        receivedElement = [[NSMutableString alloc] init];
        currentElement = kInvalidElementType;
        processingElement = NO;
        
        self.xmppRoster = [[CKRoster alloc] init];
    }
    
    return self;
}

#pragma mark Socket/Stream Methods

- (BOOL)writeRawBytes:(NSData *)messageBytes toStream:(NSOutputStream *)stream
{
    int attempt_count = 0;
    const uint8_t *raw_message = (const uint8_t *)[messageBytes bytes];
    NSInteger bytes_left = [messageBytes length];
    while (bytes_left > 0) {
        NSInteger bytes_written = [stream write:raw_message 
                                      maxLength:bytes_left];
        bytes_left = bytes_left - bytes_written;

        // only try 10 times, afterwards, return false
        if (attempt_count++ > 10 && bytes_left > 0) {
            return NO;
        }
    }
    return TRUE;
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
    //CKDebug(@"eventCode: %lu", eventCode);
    switch (eventCode) {
        case NSStreamEventErrorOccurred:
        {
            CKDebug(@"[-] NSStreamEventErrorOccurred Occured.");
            CKDebug(@"[-] Stopping Stream Processor");
            [self logoutOfService];
            break;
        }
        case NSStreamEventEndEncountered:
        {
            CKDebug(@"[-] NSStreamEventEndEncountered Occured.");
            CKDebug(@"[-] Stopping Stream Processor");
            [self logoutOfService];
            break;
        }
        default:
            break;
    }
    // NSStreamEventNone                 0 << 0      0
    // NSStreamEventOpenCompleted        1 << 0      1
    // NSStreamEventHasBytesAvailable    1 << 1      2
    // NSStreamEventHasSpaceAvailable    1 << 2      4
    // NSStreamEventErrorOccurred        1 << 3      8
    // NSStreamEventEndEncountered       1 << 4      16
}


- (void)loginToServiceWithUsername:(NSString *)username password:(NSString *)password
{
    self.username = username;
    self.password = password;
    
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    
    CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, 
                                       (__bridge CFStringRef)@"talk.google.com", 
                                       5223, 
                                       &readStream, 
                                       &writeStream);
    
    inputStream = CFBridgingRelease(readStream);
    outputStream = CFBridgingRelease(writeStream);
    
    [outputStream setDelegate:self];
    
    [inputStream  scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    // use ssl
    [inputStream  setProperty:NSStreamSocketSecurityLevelNegotiatedSSL 
                       forKey:NSStreamSocketSecurityLevelKey];
    [outputStream setProperty:NSStreamSocketSecurityLevelNegotiatedSSL 
                       forKey:NSStreamSocketSecurityLevelKey];
    
    [inputStream open];
    [outputStream open];
    
       
    xmlParser = [[NSXMLParser alloc] initWithStream:inputStream];
    [xmlParser setDelegate:self];
    
    // xmlparser block
    dispatch_block_t dispatch_block = ^(void)
    {
        if (xmlParser != nil) {
            [xmlParser parse];
        }
    };
    
    // start a timer that fires every 60 seconds to send a keep alive ping to the server
    serverPingTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:60]
        interval:60 target:self selector:@selector(sendServerPing:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:serverPingTimer forMode:NSDefaultRunLoopMode];

    // dispatch messages to queue
    dispatch_async(dispatch_queue, dispatch_block);
    
    // get initial stream message bytes
    NSData *stanza = [CKStanzaLibrary startStreamWithDomain:@"gmail.com"];
    self.streamState = kStateWaitingForStream;
    
    // write to socket
    [self writeRawBytes:stanza toStream:outputStream];
}

- (void)logoutOfService
{
    // close and start cleaning up stream
    NSData *stanza = [CKStanzaLibrary stopStream];
    [self writeRawBytes:stanza toStream:outputStream];
    
    // update instantmessageaccount state
    self.streamState = kStateNotConnected;
    self.signedIn = NO;
    
    // clear xml parser state
    [receivedElement setString:@""];
    currentElement = kInvalidElementType;
    processingElement = NO;
    
    // disable the server ping timer
    if (serverPingTimer != nil) {
        [serverPingTimer invalidate];
        serverPingTimer = nil;
    }
    
    // notify chattakit that we are disconnected
    if (self.delegate != nil) {
        [self.delegate connectionStateNotificationFrom:self connected:NO];
    }
    
    // block to execute
    dispatch_block_t dispatch_block = ^(void)
    {
        if (inputStream != nil) {
            [inputStream close];
            [inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] 
                                   forMode:NSDefaultRunLoopMode];
            inputStream = nil;
        }
        if (outputStream != nil) {
            [outputStream close];
            [outputStream setDelegate:nil];
            [outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] 
                                    forMode:NSDefaultRunLoopMode];
            outputStream = nil;
        }
        
        if (xmlParser != nil) {
            [xmlParser setDelegate:nil];
            [xmlParser abortParsing];
            xmlParser = nil;
        }
    };
    
    // dispatch
    dispatch_async(dispatch_queue, dispatch_block);
}

- (void)sendMessage:(NSString *)message toContact:(CKContact *)contact
{
    // create message stanza
    NSData *stanza = [CKStanzaLibrary messageFrom:self.fullJabberIdentifier 
                                              to:contact.jabberIdentifier
                                          withId:self.infoQueryIdentifier 
                                          andMsg:message];
    
    // if successfully send message, contact notify contact delegate of new message
    BOOL writeSuccess = [self writeRawBytes:stanza toStream:outputStream];
    if (writeSuccess) {
        CKContact *me = [CKContactList sharedInstance].me;
        CKMessage *newMessage = [[CKMessage alloc] initWithContact:me 
            timestamp:[NSDate date] messageText:message];
        [[CKContactList sharedInstance] newMessage:newMessage forContact:contact];
    }
}

- (void)sendPresenceProbeTo:(CKContact *)contact
{
    CKRosterItem *rosterItem =
        [self.xmppRoster rosterItemForBareJabberIdentifier:contact.jabberIdentifier];
    if (rosterItem.online == YES) {
        contact.connectionState = ContactStateOnline;
        return;
    }
    contact.connectionState = ContactStateOffline;
}

- (void)sendExtendedAttributesQuery
{
    // create message stanza
    NSData *stanza = [CKStanzaLibrary extendedAttributesQuery:self.fullJabberIdentifier];
    
    // send ping
    [self writeRawBytes:stanza toStream:outputStream];
}

// selector for server ping keep alive
- (void)sendServerPing:(NSTimer *)timer
{
    // create message stanza
    NSData *stanza = [CKStanzaLibrary pingFrom:self.fullJabberIdentifier 
                                       withId:self.infoQueryIdentifier];
    
    // send ping
    [self writeRawBytes:stanza toStream:outputStream];
}

#pragma mark Element Processor methods

- (void)processElement:(NSString *)element andElementType:(XMLElementType)elementType
{    
    //CKDebug(@"processElement: %@", element);
    CKXMLDocument *xmlDocument =
        [[CKXMLDocument alloc] initWithXMLString:element options:CKXMLDocumentTidyXML];
    
    // stream level errors are unrecoverable, shut down the stream if an error has occured
    if ([xmlDocument containsElementsWithName:@"stream:error"]) {
        [self logoutOfService];
    }
    
    switch (self.streamState) {
        case kStateWaitingForStream:
        {
            self.streamState = kStateWaitingForFeatures;
            break;
        }
        case kStateWaitingForFeatures:
        {            
            // check if the server supports the PLAIN authentication mechanism  
            BOOL containsPLAIN = NO;
            NSArray *mechanisms = [[[xmlDocument elementsForName:@"mechanisms"] lastObject] 
                                   elementsForName:@"mechanism"];
            for (CKXMLDocument *m in mechanisms) {
                if ([m.content isEqualToString:@"PLAIN"]) {
                    containsPLAIN = YES;
                    break;
                }
            }
            
            // if it doesn't, stop the stream, currently only PLAIN is supported
            if (containsPLAIN == NO) {
                [self logoutOfService];
            }
            
            NSData *stanza = [CKStanzaLibrary authWithUsername:self.username password:self.password];
            [self writeRawBytes:stanza toStream:outputStream];
            self.streamState = kStateWaitingForAuth;
            break;
        }
        case kStateWaitingForAuth:
        {            
            // login successful
            if ([xmlDocument.name isEqualToString:@"success"]) {
                CKDebug(@"[+] login to instant service successful");
                NSData *stanza = [CKStanzaLibrary sessionStreamWithJabberIdentifier:self.username 
                                                                         domain:@"gmail.com"];
                [self writeRawBytes:stanza toStream:outputStream];
                self.streamState = kStateWaitingForSessionStream;
            }
            // failure
            else {
                CKDebug(@"[-] login failure");
                [self logoutOfService];
            }
            
            break;
        }
        case kStateWaitingForSessionStream:
        {
            if ([xmlDocument.name isEqualToString:@"stream"]) {
                self.streamState = kStateWaitingForFeaturesBindSession;
            } else {
                [self logoutOfService];
            }
            break;
        }
        case kStateWaitingForFeaturesBindSession:
        {
            if ([xmlDocument elementsForName:@"bind"].count > 0) {
                self.infoQueryIdentifier = [NSString randomStringWithLength:8];
                NSData *stanza = [CKStanzaLibrary 
                                  infoQueryBindWithRandomIdentifier:self.infoQueryIdentifier];
                [self writeRawBytes:stanza toStream:outputStream];
                self.streamState = kStateWaitingForInfoQueryBind;
            } else { 
                [self logoutOfService];
            }
            break;
        }
        case kStateWaitingForInfoQueryBind:
        {
            if ([xmlDocument containsElementsWithName:@"error"]) {
                [self logoutOfService];
            }
            // extract jid
            CKXMLDocument *bindtag = [xmlDocument.elements lastObject];
            CKXMLDocument *jidtag = [[bindtag elementsForName:@"jid"] lastObject];
            self.fullJabberIdentifier = jidtag.content;
            
            // send iq request for roster and presence to indicate we're online
            NSData *stanza = [CKStanzaLibrary
                infoQueryRequestRosterAndPresenceWithJabberIdentifier:self.fullJabberIdentifier
                andIdentifier:self.infoQueryIdentifier];
            [self writeRawBytes:stanza toStream:outputStream];
            self.streamState = kStateConnected;
            self.signedIn = YES;
            if (self.delegate != nil) {
                [self.delegate connectionStateNotificationFrom:self connected:YES];
            }
            
            CKDebug(@"[+] connection to instant service established");
            break;
        }
        case kStateConnected:
        {
            switch (elementType) {
                case kStanzaInfoQuery:
                {
                    CKXMLDocument *query = [[xmlDocument elementsForName:@"query"] lastObject];
                    
                    /* ignore ping response iq from server */
                    
                    /* parse extended attributes */
                    NSString *queryId = [xmlDocument.attributes objectForKey:@"id"];
                    if (queryId != nil && [queryId isEqualToString:@"google-roster-1"]) {
                        CKContactMerger *contactMerger = [[CKContactMerger alloc] init];
                        if (self.delegate != nil) {
                            [self.delegate mostContactedFrom:self
                                contacts:[contactMerger mostContactedFrom:xmlDocument]];
                        }
                        break;
                    }
                    
                    /* fill in roster with bare jids */
                    NSString *queryNamespace = [query.xmlns objectAtIndex:0];
                    if ([queryNamespace isEqualToString:@"xmlns=\'jabber:iq:roster\'"]) {
                        for (CKXMLDocument *item in query.elements) {
                            CKRosterItem *rosterItem = [[CKRosterItem alloc] init];
                            rosterItem.bareJabberIdentifier = [item.attributes objectForKey:@"jid"];
                            rosterItem.online = NO;
                            [self.xmppRoster addRosterItem:rosterItem];
                        }
                        break;
                    }
                    
                    // disco info response
                    if ([[query.xmlns lastObject]
                            isEqualToString:@"xmlns='http://jabber.org/protocol/disco#info'"]) {
                        NSString *from = [xmlDocument.attributes objectForKey:@"from"];
                        NSString *bareFrom = [[from componentsSeparatedByString:@"/"] objectAtIndex:0];
                    
                        // send iq request for roster and presence to indicate we're online
                        NSData *stanza = [CKStanzaLibrary
                            infoQueryDiscoveryInfoResponseFrom:self.fullJabberIdentifier andTo:bareFrom];
                        [self writeRawBytes:stanza toStream:outputStream];
                        break;
                    }
                    break;
                }
                case kStanzaPresence:
                {
                    NSString *contactFullJid = [xmlDocument.attributes objectForKey:@"from"];
                    NSString *contactBareJid =
                        [[contactFullJid componentsSeparatedByString:@"/"] objectAtIndex:0];
                    CKContact *contact =
                        [[CKContactList sharedInstance] contactWithJabberIdentifier:contactBareJid];
                    
                    // contact signed off
                    if ([[xmlDocument.attributes objectForKey:@"type"] isEqualToString:@"unavailable"]) {
                        // remove from roster
                        CKRosterItem *rosterItem =
                            [self.xmppRoster rosterItemForBareJabberIdentifier:contactBareJid];
                        if (rosterItem != nil) {
                            rosterItem.online = NO;
                        }
                  
                        // update chatta
                        contact.connectionState = ContactStateOffline;
                    }
                    // contact requested to add you to their buddy list
                    else if ([[xmlDocument.attributes objectForKey:@"type"] isEqualToString:@"subscribe"]) {
                        CKDebug(@"[+] friend request from contact: %@", contactFullJid);
                    }
                    // contact signed on
                    else {
                        // add to roster
                        CKRosterItem *rosterItem =
                            [self.xmppRoster rosterItemForBareJabberIdentifier:contactBareJid];
                        if (rosterItem == nil) {
                            rosterItem = [[CKRosterItem alloc] init];
                            rosterItem.bareJabberIdentifier = contactBareJid;
                        }
                        rosterItem.online = YES;
                        rosterItem.fullJabberIdentifier = contactFullJid;
                        [self.xmppRoster addRosterItem:rosterItem];

                        // update chatta
                        contact.connectionState = ContactStateOnline;
                    }

                    break;
                }
                case kStanzaMessage:
                {
                    NSString *contactFullJid = [xmlDocument.attributes objectForKey:@"from"];
                    NSString *contactBareJid =
                        [[contactFullJid componentsSeparatedByString:@"/"] objectAtIndex:0];
                    CKContact *contact =
                        [[CKContactList sharedInstance] contactWithJabberIdentifier:contactBareJid];

                    // if we don't have a body element, we are not interested
                    // this is usually things like indicating the other user 
                    // is typing 
                    NSArray *bodyElements = [xmlDocument elementsForName:@"body"];
                    if (bodyElements == nil) { 
                        return;
                    }
                    
                    // extract body
                    CKXMLDocument *bodyElement = [bodyElements objectAtIndex:0];
                    NSString *messageText = [bodyElement.content stringByRemovingWhitespaceNewlineChars];

                    CKDebug(@"[+] received message: %@; from: %@", messageText, contactBareJid);
                    
                    if (contact == nil) {
                        contact = [[CKContact alloc] initWithJabberIdentifier:contactBareJid
                            andDisplayName:contactBareJid andPhoneNumber:nil
                            andContactState:ContactStateOnline];
                        [[CKContactList sharedInstance] addContact:contact];
                    }
                    CKMessage *message = [[CKMessage alloc] initWithContact:contact
                        timestamp:[NSDate date] messageText:messageText];
                    [[CKContactList sharedInstance] newMessage:message forContact:contact];
                   
                    break;
                }
                default:
                    break;
            }
            
            break;
        }
        case kStateInvalidState:
        default:
            break;
    }
}

#pragma mark NSXMLParser Methods

- (void)clearParserState
{
    [receivedElement setString:@""];
    currentElement = kInvalidElementType;
    processingElement = NO;
}

-  (void)parser:(NSXMLParser *)parser 
didStartElement:(NSString *)elementName 
   namespaceURI:(NSString *)namespaceURI 
  qualifiedName:(NSString *)qName 
     attributes:(NSDictionary *)attributeDict
{
    //CKDebug(@"didStartElement: %@", elementName);
    // if we are not processing any element, start processing of a new element
    if (processingElement == NO) {
        currentElement = [CKStanzaLibrary elementTypeForName:elementName];
        processingElement = YES;
    }
    
    // fill in xml element attributes
    [receivedElement appendString:[NSString stringWithFormat:@"<%@", elementName]];
    for (NSString *key in [attributeDict allKeys]) {
        NSString *value = [attributeDict valueForKey:key];
        [receivedElement appendString:[NSString stringWithFormat:@" %@=\'%@\'", key, value]];
    }
    [receivedElement appendString:[NSString stringWithFormat:@">"]];
    
    // if this is a stream element, it doesn't have anything else, process it immediately
    if (currentElement == kStreamStream) {
        [self processElement:receivedElement andElementType:currentElement];
        [self clearParserState];
    }
    if (currentElement == kStreamError) {
        [self processElement:receivedElement andElementType:currentElement];
        [self clearParserState];
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    //CKDebug(@"foundCharacters: %@", string);
    if (processingElement == YES) {
        [receivedElement appendString:string];
    }
}

- (void)parser:(NSXMLParser *)parser 
 didEndElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI 
 qualifiedName:(NSString *)qName
{
    //CKDebug(@"didEndElement: %@", elementName);
    if (processingElement == YES) {
        // if the element type is the one currently being processed, we've
        // reached the end, send it off for processing
        XMLElementType incomingElement = [CKStanzaLibrary elementTypeForName:elementName];
        if (currentElement == incomingElement) {
            [receivedElement appendString:[NSString stringWithFormat:@"</%@>", elementName]];
            [self processElement:receivedElement andElementType:currentElement];
            [self clearParserState];
        }
        // otherwise, keep appending
        else { 
            [receivedElement appendString:[NSString stringWithFormat:@"</%@>", elementName]];
        }
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    CKDebug(@"[-] SAX Error %ld, Description: %@, Line: %ld, Column: %ld", 
            [parseError code], [parseError localizedDescription], 
            [parser lineNumber], [parser columnNumber]);
}

@end
