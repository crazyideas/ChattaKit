//
//  CKTextMessageService.m
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import "CKTextMessageService.h"
#import "NSString+CKAdditions.h"
#import "CKTimeService.h"
#import "CKContactList.h"
#import "CKXMLDocument.h"
#import "CKContact.h"
#import "CKMessage.h"
#import "CKTimer.h"


@interface CKTextMessageService (PrivateMethods)
- (BOOL)fetchAccountKeys;
- (NSString *)timezoneRequest;
- (NSString *)sendKeyRequest;
- (NSString *)refreshKeyRequest;

- (void)startFetchUnreadMessagesTimer;
- (void)stopFetchUnreadMessagesTimer;
- (BOOL)markMessageAsRead:(NSString *)messageIdentification;

- (NSString *)rawHttpRequest:(NSString *)method onURL:(NSString *)url withBody:(NSString *)body;
@end


@implementation CKTextMessageService

#pragma mark - CKTextMessageService Public Methods

- (id)init {
    self = [super init];
    if (self != nil) {
        dispatch_queue = dispatch_queue_create("text.service.queue", NULL);
    }
    return self;
}

- (void)loginToServiceWithUsername:(NSString *)username password:(NSString *)password
{
    __block CKTextMessageService *block_self = self;

    dispatch_async(dispatch_queue, ^(void) {
        
        NSString *requestBody = [NSString stringWithFormat:
                                 @"accountType=%@&Email=%@&Passwd=%@&service="
                                 @"grandcentral&source=crazyideas-chatta-0.2",
                                 @"GOOGLE", username, password];
        
        NSString *requestResult = [block_self rawHttpRequest:@"POST" 
            onURL:SERVICE_CLIENT_LOGIN_URL withBody:requestBody];
        
        if (requestResult == nil) {
            CKDebug(@"[-] (login, text service) rawHttpRequest failed");
            if (block_self.delegate != nil) {
                [block_self.delegate connectionStateNotificationFrom:block_self connected:NO];
            }
            return;
        }
        
        for (NSString *errorCode in [CKConstants serviceErrorCodes]) {
            if ([requestResult rangeOfString:errorCode].location != NSNotFound) {
                CKDebug(@"[-] connection failed due to code: %@", errorCode);
                if (block_self.delegate != nil) {
                    [block_self.delegate connectionStateNotificationFrom:block_self connected:NO];
                }
                return;
            }
        }
        
        // connection was successful, extract tokens and put them in dictionary
        NSCharacterSet *newLineCharSet = [NSCharacterSet newlineCharacterSet];
        NSMutableDictionary *tokens = [[NSMutableDictionary alloc] init];
        NSArray *tokenLines = [requestResult componentsSeparatedByCharactersInSet:newLineCharSet];
        for (NSString *tk in tokenLines) {
            NSArray *toks = [tk componentsSeparatedByString:@"="];
            if (toks != nil && toks.count > 1) {
                NSString *key   = [NSString stringWithString:[toks objectAtIndex:0]];
                NSString *value = [NSString stringWithString:[toks objectAtIndex:1]];
                [tokens setValue:value forKey:key];
            }
        }
        
        // set authorizationToken
        block_self.textAuthToken = [NSString stringWithString:[tokens objectForKey:@"Auth"]];
        if (block_self.textAuthToken == nil) {
            CKDebug(@"[-] connection failed, authorizationToken is nil");
            if (block_self.delegate != nil) {
                [block_self.delegate connectionStateNotificationFrom:block_self connected:NO];
            }
            return;
        }
        
        // fetch account keys (_rnr_se, r, and timezone)
        if ([block_self fetchAccountKeys] == NO) {
            CKDebug(@"[-] connection failed, account keys not fetched");
            if (block_self.delegate != nil) {
                [block_self.delegate connectionStateNotificationFrom:block_self connected:NO];
            }
            return;
        }
        
        CKDebug(@"[+] login to text service successful");
        CKDebug(@"[+] connection to text service established");

        // setup time service
        CKTimeService *timeService = [CKTimeService sharedInstance];
        [timeService setServiceTimeZone:block_self.accountTimezone];
        
        [block_self startFetchUnreadMessagesTimer];
        if (block_self.delegate != nil) {
            [block_self.delegate connectionStateNotificationFrom:block_self connected:YES];
        }
    });
}

- (void)logoutOfService
{
    self.textAuthToken     = nil;
    self.accountTimezone   = nil;
    self.accountSendKey    = nil;
    self.accountRefreshKey = nil;
    
    [self stopFetchUnreadMessagesTimer];
    if (self.delegate != nil) {
        [self.delegate connectionStateNotificationFrom:self connected:NO];
    }
}

- (void)sendMessage:(NSString *)message toContact:(CKContact *)contact
{
    __block CKTextMessageService *block_self = self;

    dispatch_async(dispatch_queue, ^(void) {

        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDate *now = [NSDate date];
        
        // check if authorizationToken has value
        if (block_self.textAuthToken == nil) {
            return;
        }
        
        // if close to a minute change interval, delay, then send. this way we maintain 
        // sync between chattakit and text service. we can sleep in this thread because
        // it doesn't block the main UI thread
        NSDateComponents *nowComponents = [calendar components:NSSecondCalendarUnit fromDate:now];
        if (nowComponents.second > 55) {
            // delay by 6 seconds then send
            now = [now dateByAddingTimeInterval:6];
            [NSThread sleepForTimeInterval:6];
        }
        
        // url encoded versions of all information being sent
        
        
        NSString *phoneNumberEncoded = [contact.phoneNumber stringWithUrlEncoding];
        NSString *messageTextEncoded = [message stringWithUrlEncoding];
        NSString *sendKeyTextEncoded = [block_self.accountSendKey stringWithUrlEncoding];
        
        // create bytes of http post body
        NSString *requestBody = [NSString stringWithFormat:@"phoneNumber=%@&text=%@&_rnr_se=%@", 
                                 phoneNumberEncoded, messageTextEncoded, sendKeyTextEncoded];

        NSString *requestResult = [block_self rawHttpRequest:@"POST" 
            onURL:SERVICE_SEND_URL withBody:requestBody];
        
        if (requestResult == nil) {
            CKDebug(@"[-] rawHttpRequest failed");
            return;
        }
        
        if ([requestResult isEqualToString:@"{\"ok\":true,\"data\":{\"code\":0}}"]) {
            CKContact *me = [CKContactList sharedInstance].me;
            CKMessage *newMessage = [[CKMessage alloc] initWithContact:me
                timestamp:now messageText:message];
            [[CKContactList sharedInstance] newMessage:newMessage forContact:contact];
        }
    });
}

- (void)dealloc
{
    if (dispatch_queue) {
        dispatch_release(dispatch_queue);
    }
}

#pragma mark - Parsing, Formatting, and Merging Methods

- (CKContact *)contactForThread:(NSString *)threadId jsonLookup:(NSDictionary *)jsonDictionary
{
    NSDictionary *messages = [jsonDictionary objectForKey:@"messages"];
    if (messages == nil) {
        return nil;
    }
    
    NSDictionary *thread = [messages objectForKey:threadId];
    if (thread == nil) {
        return nil;
    }
    
    NSString *contactPhoneNumber = [thread objectForKey:@"phoneNumber"];
    if (contactPhoneNumber == nil) {
        return nil;
    }
    
    CKContact *contact = [[CKContactList sharedInstance] contactWithPhoneNumber:contactPhoneNumber];
    if (contact == nil) {
        contact = [[CKContact alloc] initWithJabberIdentifier:nil andDisplayName:contactPhoneNumber
            andPhoneNumber:contactPhoneNumber andContactState:ContactStateOffline];
        [[CKContactList sharedInstance] addContact:contact];
    }
    return contact;
}

- (NSDate *)anchorForThread:(NSString *)threadId jsonLookup:(NSDictionary *)jsonDictionary
{
    NSDictionary *messages = [jsonDictionary objectForKey:@"messages"];
    if (messages == nil) {
        return nil;
    }
    
    NSDictionary *thread = [messages objectForKey:threadId];
    if (thread == nil) {
        return nil;
    }
    
    NSString *displayStartDateTime = [thread objectForKey:@"displayStartDateTime"];
    if (displayStartDateTime == nil) {
        return nil;
    }

    return [NSDate dateWithNaturalLanguageString:displayStartDateTime];
}

- (void)cleanupMessageDates:(NSArray *)messages withAnchor:(NSDate *)anchorDate
{
    CKTimeService *timeService = [CKTimeService sharedInstance];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"MM/dd/YYYY";
    NSString *anchorDateString = [dateFormatter stringFromDate:anchorDate];
    dateFormatter.dateFormat = @"hh:mm a";
    NSString *anchorTimeString = [dateFormatter stringFromDate:anchorDate];
    dateFormatter.dateFormat = @"a";
    NSString *anchorAmPm = [dateFormatter stringFromDate:anchorDate];
    
    BOOL anchorSet = FALSE;
    BOOL isAnchorAm = ([anchorAmPm isEqualToString:@"AM"]) ? YES : NO;
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    // find anchor point, and convert date strings into date objects. 
    
    // first we do this backwards, because
    // the anchor point (full datetime string) provided 
    // by google is usually the last message, or second 
    // to last message
    for (CKMessage *m in [messages reverseObjectEnumerator]) {
        if ([m.timestampString isEqualToString:anchorTimeString]) {
            m.timestamp = anchorDate;
            
            // adjust the timezone to be the system timezone
            dateFormatter.dateFormat = @"hh:mm a";
            m.timestamp = [timeService dateInSystemTimeZone:m.timestamp];
            m.timestampString = [dateFormatter stringFromDate:m.timestamp];
            
            anchorSet = TRUE;
            continue;
        }
        if (anchorSet == TRUE) {
            // check if am/pm switch has occured
            BOOL isDatePm = ([[m.timestampString substringFromIndex:[m.timestampString length]-2] 
                              isEqualToString:@"PM"]) ? YES : NO;
            if (isAnchorAm && isDatePm) {
                // if the anchor started as am, and time has changed to pm, 
                // subtract anchor date by one
                NSDate *dateMinusOneDay = anchorDate;
                NSDateComponents *componentToSubtract = [[NSDateComponents alloc] init];
                componentToSubtract.day = -1;
                dateMinusOneDay = [calendar dateByAddingComponents:componentToSubtract 
                                                            toDate:dateMinusOneDay options:0];
                
                // regenerate anchorDateString
                dateFormatter.dateFormat = @"MM/dd/YYYY";
                anchorDateString = [dateFormatter stringFromDate:dateMinusOneDay];
            }
            // concat the date component and time components to make a new nsdate
            NSString *newDateString = [NSString stringWithFormat:@"%@ %@", 
                                       anchorDateString, m.timestampString];
            m.timestamp = [NSDate dateWithNaturalLanguageString:newDateString];
            
            // adjust the timezone to be the system timezone
            dateFormatter.dateFormat = @"hh:mm a";
            m.timestamp = [timeService dateInSystemTimeZone:m.timestamp];
            m.timestampString = [dateFormatter stringFromDate:m.timestamp];
        }
    }
    
    // reset anchorDateString
    dateFormatter.dateFormat = @"MM/dd/YYYY";
    anchorDateString = [dateFormatter stringFromDate:anchorDate];
    
    // go forward and processing any remaining messages
    for (CKMessage *m in messages) {
        if (m.timestamp == nil) {
            // check if am/pm switch has occured
            BOOL isDatePm = ([[m.timestampString substringFromIndex:[m.timestampString length]-2] 
                              isEqualToString:@"PM"]) ? YES : NO;
            if (!isAnchorAm && !isDatePm) {
                // if the anchor started as pm, and time has changed to am, 
                /// increment anchor date by one
                NSDate *datePlusOneDay = anchorDate;
                NSDateComponents *componentToAdd = [[NSDateComponents alloc] init];
                componentToAdd.day = +1;
                datePlusOneDay = [calendar dateByAddingComponents:componentToAdd 
                                                           toDate:datePlusOneDay 
                                                          options:0];
                
                // regenerate anchorDateString
                dateFormatter.dateFormat = @"MM/dd/YYYY";
                anchorDateString = [dateFormatter stringFromDate:datePlusOneDay];
            }
            // concat the date component and time components to make a new nsdate
            NSString *newDateString = [NSString stringWithFormat:@"%@ %@", 
                                       anchorDateString, m.timestampString];
            m.timestamp = [NSDate dateWithNaturalLanguageString:newDateString];
            
            // adjust the timezone to be the system timezone
            dateFormatter.dateFormat = @"hh:mm a";
            m.timestamp = [timeService dateInSystemTimeZone:m.timestamp];
            m.timestampString = [dateFormatter stringFromDate:m.timestamp];
        }
    }
    
    // one last pass over all messages, estimate seconds for multiple messages
    // with the same minute value so they are correctly ordered by the controller
    NSString *previousDateString = nil;
    int count = 0;
    for (CKMessage *m in messages) {
        if ([m.timestampString isEqualToString:previousDateString]) {
            // if the same time is repeated, add two seconds
            m.timestamp = [m.timestamp dateByAddingTimeInterval:++count];
        } else { 
            count = 0;
        }
        // update previous date string
        previousDateString = m.timestampString;
    }
}

- (void)mergeNewMessages:(NSArray *)messages forContact:(CKContact *)contact
{
    NSMutableSet *diffSet = [NSMutableSet setWithArray:messages];
    [diffSet minusSet:[NSSet setWithArray:contact.messages]];
    
    NSSortDescriptor *sortDesc = [[NSSortDescriptor alloc] initWithKey:@"timestamp" ascending:YES];
    NSArray *diffArray = [diffSet sortedArrayUsingDescriptors:[NSArray arrayWithObject:sortDesc]];
    for (CKMessage *diffMessage in diffArray) {
        NSString *fromDisplay = (diffMessage.contact.phoneNumber) ?
            diffMessage.contact.phoneNumber : diffMessage.contact.displayName;
        CKDebug(@"[+] received message: %@; from: %@", diffMessage.text, fromDisplay);
        [[CKContactList sharedInstance] newMessage:diffMessage forContact:contact];
    }
}

- (void)parseMessagesJSON:(NSData *)jsonResponse andHTML:(NSData *)htmlResponse
{
    NSError *jsonParsingError = nil;
    
    NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:jsonResponse 
        options:0 error:&jsonParsingError];
    
    if(jsonParsingError != nil) {
        CKDebug(@"[-] json parsing error: %@", jsonParsingError);
        return;
    }
    
    // init parser and grab root node of document
    NSString *htmlResponseString =
        [[NSString alloc] initWithData:htmlResponse encoding:NSUTF8StringEncoding];
    CKXMLDocument *htmlDocument =
        [[CKXMLDocument alloc] initWithHTMLString:htmlResponseString options:CKXMLDocumentTidyHTML];
    
    // iterate over all threads
    NSDictionary *allThreads = [jsonDictionary objectForKey:@"messages"];
    for (NSString *threadId in allThreads) {
        NSMutableArray *conversation = [[NSMutableArray alloc] init];
        CKContact *contact = [self contactForThread:threadId jsonLookup:jsonDictionary];

        NSString *xpathExpr = [NSString stringWithFormat:
                               @"//div[@id=\'%@\' and @class=\'%@\']//div[@class=\'%@\']",
                               threadId, DIV_ID_NODE_CLASS, DIV_MESSAGE_CLASS];
        NSArray *messageElements = [htmlDocument elementsForXpathExpression:xpathExpr];
        for (CKXMLDocument *messageElement in messageElements) {
            // by default set all messages names to other party, on instances of 
            // "Me:", replace with self full name
            CKMessage *message = [[CKMessage alloc] initWithContact:contact];
            
            NSArray *spanElements = [messageElement elementsForName:@"span"];
            for (CKXMLDocument *span in spanElements) {
                NSString *classAttr = [span.attributes objectForKey:@"class"];
                if ([classAttr isEqualToString:SPAN_MESSAGE_TEXT_CLASS]) { 
                    message.text = [span.content stringByRemovingWhitespaceNewlineChars];
                } else if ([classAttr isEqualToString:SPAN_MESSAGE_TIME_CLASS]) {
                    message.timestampString = [span.content stringByRemovingWhitespaceNewlineChars];
                } else if ([classAttr isEqualToString:SPAN_MESSAGE_FROM_CLASS]) {
                    NSString *fromName = [span.content stringByRemovingWhitespaceNewlineChars];
                    if ([fromName isEqualToString:@"Me:"]) {
                        message.contact = [CKContactList sharedInstance].me;
                    }
                }
            }
            [conversation addObject:message];
        }
        
        // using the thread anchor date (message start date according to google voice, which is 
        // actually usually the message end date, but not all the time), convert all the date 
        // strings into date objects
        NSDate *anchorDate = [self anchorForThread:threadId jsonLookup:jsonDictionary];
        [self cleanupMessageDates:conversation withAnchor:anchorDate];
        
        // merge the new messages back into the conversation, if there are new messages, 
        // contact will inform his delegate
        [self mergeNewMessages:conversation forContact:contact];
        
        // mark message as read
        [self markMessageAsRead:threadId];

    }
}



#pragma mark - CKTextMessageService Private Methods

- (BOOL)fetchAccountKeys
{
    // update send key (_rnr_se)
    self.accountSendKey = [self sendKeyRequest];
    if (self.accountSendKey == nil) {
        CKDebug(@"[-] unable to retrieve account send key");
        return NO;
    }
    
    // update refresh key (r)
    self.accountRefreshKey = [self refreshKeyRequest];
    if (self.accountRefreshKey == nil) {
        CKDebug(@"[-] unable to retrieve account refresh key");
        return NO;
    }
    
    // update account timezone value
    self.accountTimezone = [self timezoneRequest];
    if (self.accountTimezone == nil) {
        CKDebug(@"[-] unable to retrieve account Timezone");
        return NO;
    }
    
    return YES;
}

- (NSString *)timezoneRequest
{
    if (self.textAuthToken == nil) {
        return nil;
    }
    
    NSString *requestResult = [self rawHttpRequest:@"GET" onURL:SERVICE_SETTINGS_URL withBody:nil];
    if (requestResult == nil) {
        return nil;
    }
    
    // this is a very hacky/brittle way to do this, another (slightly) better 
    // option is to parse the xml, find instances of cdata, parse the json, 
    // put it in a dictonary, then extract the timezone value, however, that 
    // is just as likley to break with any changes as this method is
    NSRange range1 = [requestResult rangeOfString:@"timezone\":\""];
    NSRange range2 = [requestResult rangeOfString:@"\",\"doNotDisturb"];
    if (range1.location == NSNotFound || range2.location == NSNotFound) {
        return nil;
    }
    
    NSUInteger length = range2.location - range1.location - range1.length;
    NSUInteger location = range1.location + range1.length;
    NSRange tzRange = NSMakeRange(location, length);
    return [requestResult substringWithRange:tzRange];
}

- (NSString *)sendKeyRequest
{
    NSString *_rnr_se;

    if (self.textAuthToken == nil) {
        return nil;
    }
    
    NSString *requestResult = [self rawHttpRequest:@"GET" onURL:SERVICE_MAIN_PAGE_URL withBody:nil];
    if (requestResult == nil) {
        return nil;
    }
    
    // init parser
    CKXMLDocument *htmlDocument =
        [[CKXMLDocument alloc] initWithHTMLString:requestResult options:CKXMLDocumentTidyHTML];
    NSArray *inputNodes = [htmlDocument elementsForXpathExpression:@"//input[@name]"];
    CKXMLDocument *rnrseElement = nil;
    for (CKXMLDocument *inputElement in inputNodes) {
        if ([[[inputElement attributes] objectForKey:@"name"] isEqualToString:@"_rnr_se"]) {
            rnrseElement = inputElement;
            break;
        }
    }
    
    if (rnrseElement == nil) {
        return nil;
    }
    
    _rnr_se = [[NSString alloc] initWithString:[rnrseElement.attributes objectForKey:@"value"]];
    
    return _rnr_se;
}

- (NSString *)refreshKeyRequest
{
    if (self.textAuthToken == nil) {
        return nil;
    }
    
    NSString *requestResult = [self rawHttpRequest:@"GET" onURL:SERVICE_XPC_URL withBody:nil];
    if (requestResult == nil) {
        return nil;
    }
    
    // this is a very hacky/brittle way to do this, but I don't want to parse 
    // the xml, find instances of cdata, parse the json, put it in a dictonary, 
    // then extract the timezone value. if this breaks in the future, that is 
    // the correct way to extract the timezone
    NSRange range1 = [requestResult rangeOfString:@"_cd(\'"];
    NSRange range2 = [requestResult rangeOfString:@"\', null"];
    if (range1.location == NSNotFound || range2.location == NSNotFound) {
        return nil;
    }
    
    NSUInteger length = range2.location - range1.location - range1.length;
    NSUInteger location = range1.location + range1.length;
    NSRange refreshKeyRange = NSMakeRange(location, length);
    return [requestResult substringWithRange:refreshKeyRange];
}

- (void)startFetchUnreadMessagesTimer
{
    __block CKTextMessageService *block_self = self;

    timerBlock_t fetchUnreadMessages = ^(void) {
        CKDebug(@"[+] fetching unread messages");


        if (block_self.textAuthToken == nil) {
            CKDebug(@"[-] fetch failed, no auth token");
            return;
        }
        
        NSString *requestResult = [block_self rawHttpRequest:@"GET" 
            onURL:SERVICE_UNREAD_INBOX_URL withBody:nil];
        if (requestResult == nil) {
            CKDebug(@"[-] rawHttpRequest result failed in fetch undread, logging out");
            if (self.delegate != nil) {
                [self.delegate connectionStateNotificationFrom:block_self connected:NO];
            }
            return;
        }
    
        NSRange jsonRange1 = [requestResult rangeOfString:@"<json><![CDATA["];
        NSRange jsonRange2 = [requestResult rangeOfString:@"]]></json>"];
        if (jsonRange1.location == NSNotFound || jsonRange2.location == NSNotFound) {
            CKDebug(@"[-] rawHttpRequest result failed in to find json cdata");
            if (self.delegate != nil) {
                [self.delegate connectionStateNotificationFrom:block_self connected:NO];
            }
            return;
        }
        NSUInteger jsonLength = jsonRange2.location - jsonRange1.location - jsonRange1.length;
        NSUInteger jsonLocation = jsonRange1.location + jsonRange1.length;
        NSRange jsonRange = NSMakeRange(jsonLocation, jsonLength);
        NSData *jsonData = [[requestResult substringWithRange:jsonRange] 
                            dataUsingEncoding:NSUTF8StringEncoding];

        
        NSRange htmlRange1 = [requestResult rangeOfString:@"<html><![CDATA["];
        NSRange htmlRange2 = [requestResult rangeOfString:@"]]></html>"];
        if (htmlRange1.location == NSNotFound || htmlRange2.location == NSNotFound) {
            CKDebug(@"[-] rawHttpRequest result failed in to find html cdata");
            if (self.delegate != nil) {
                [self.delegate connectionStateNotificationFrom:block_self connected:NO];
            }
            return;
        }
        NSUInteger htmlLength = htmlRange2.location - htmlRange1.location - htmlRange1.length;
        NSUInteger htmlLocation = htmlRange1.location + htmlRange1.length;
        NSRange htmlRange = NSMakeRange(htmlLocation, htmlLength);
        NSData *htmlData = [[requestResult substringWithRange:htmlRange] 
                            dataUsingEncoding:NSUTF8StringEncoding];

        [block_self parseMessagesJSON:jsonData andHTML:htmlData];
    };
    
    self.fetchUnreadMessagesTimer = [[CKTimer alloc] initWithDispatchTime:1.0
        interval:30 queue:dispatch_queue block:fetchUnreadMessages];
}

- (void)stopFetchUnreadMessagesTimer
{
    [self.fetchUnreadMessagesTimer invalidate];
}

// check if this method is always called in a queue
- (BOOL)markMessageAsRead:(NSString *)messageIdentification
{
    if (self.textAuthToken == nil) {
        return NO;
    }
    
    NSString *requestBody = [NSString stringWithFormat:@"messages=%@&read=1&_rnr_se=%@", 
                             messageIdentification, self.accountSendKey];
    
    NSString *requestResult = [self rawHttpRequest:@"POST" 
        onURL:SERVICE_MARK_MESSAGE_URL withBody:requestBody];

    if (requestResult == nil) {
        CKDebug(@"[-] rawHttpRequest failed");
        return NO;
    }
    
    // if we successfully marked a message as read, return true
    if ([requestResult isEqualToString:@"{\"ok\":true}"]) {
        return YES;
    }
    return YES;
}

- (NSString *)rawHttpRequest:(NSString *)method onURL:(NSString *)url withBody:(NSString *)body
{
    NSMutableURLRequest *httpRequest;
    NSURLResponse *response;
    NSData *requestResult;
    NSString *authString;
    NSError *error;
    
    httpRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]
        cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    
    [httpRequest setHTTPMethod:method];
    [httpRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

    if (self.textAuthToken) {
        authString = [NSString stringWithFormat:@"GoogleLogin auth=%@", self.textAuthToken];
        [httpRequest setValue:authString forHTTPHeaderField:@"Authorization"];
    }
    
    if (body) {
        [httpRequest setHTTPBody:[NSData dataWithBytes:body.UTF8String length:body.length]];
    }
    
    
    requestResult = [NSURLConnection sendSynchronousRequest:httpRequest
        returningResponse:&response error:&error];
    
    if (error) {
        CKDebug(@"[-] connection failed with the following error: %@", error);
        return nil;
    }
    
    return [[NSString alloc] initWithData:requestResult encoding:NSUTF8StringEncoding];
}

@end