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
#import "CKXMLElement.h"
#import "CKXMLParser.h"
#import "CKContact.h"
#import "CKMessage.h"


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

@synthesize chattaKit          = _chattaKit;
@synthesize authorizationToken = _authorizationToken;
@synthesize accountTimezone    = _accountTimezone;
@synthesize accountSendKey     = _accountSendKey;
@synthesize accountRefreshKey  = _accountRefreshKey;


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
    dispatch_async(dispatch_queue, ^(void) {
        __weak CKTextMessageService *weak_self = self;
        
        NSString *requestBody = [NSString stringWithFormat:
                                 @"accountType=%@&Email=%@&Passwd=%@&service="
                                 @"grandcentral&source=crazyideas-chatta-0.1",
                                 @"GOOGLE", username, password];
        
        NSString *requestResult = [weak_self rawHttpRequest:@"POST" 
                                                      onURL:SERVICE_CLIENT_LOGIN_URL 
                                                   withBody:requestBody];
        
        if (requestResult == nil) {
            NSDebug(@"(login) rawHttpRequest failed");
            [weak_self.chattaKit connectionNotificationFrom:self withState:NO];
            return;
        }
        
        for (NSString *errorCode in [CKConstants serviceErrorCodes]) {
            if ([requestResult rangeOfString:errorCode].location != NSNotFound) {
                NSDebug(@"connection failed due to code: %@", errorCode);
                [weak_self.chattaKit connectionNotificationFrom:self withState:NO];
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
        weak_self.authorizationToken = [NSString stringWithString:[tokens objectForKey:@"Auth"]];
        if (weak_self.authorizationToken == nil) {
            NSDebug(@"connection failed, authorizationToken is nil");
            [weak_self.chattaKit connectionNotificationFrom:self withState:NO];
            return;
        }
        
        // fetch account keys (_rnr_se, r, and timezone)
        if ([weak_self fetchAccountKeys] == NO) {
            NSDebug(@"connection failed, account keys not fetched");
            [weak_self.chattaKit connectionNotificationFrom:self withState:NO];
            return;
        }
        
        NSDebug(@"login to text service successful");

        // setup time service
        CKTimeService *timeService = [CKTimeService sharedInstance];
        [timeService setServiceTimeZone:self.accountTimezone];
        
        [weak_self startFetchUnreadMessagesTimer];
        [weak_self.chattaKit connectionNotificationFrom:self withState:YES];
    });
}

- (void)logoutOfService
{
    self.authorizationToken = nil;
    self.accountTimezone    = nil;
    self.accountSendKey     = nil;
    self.accountRefreshKey  = nil;
    
    [self stopFetchUnreadMessagesTimer];
    [self.chattaKit connectionNotificationFrom:self withState:NO];
}

- (void)sendMessage:(NSString *)message toContact:(CKContact *)contact
{
    dispatch_async(dispatch_queue, ^(void) {
        __weak CKTextMessageService *weak_self = self;

        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDate *now = [NSDate date];
        
        // check if authorizationToken has value
        if (weak_self.authorizationToken == nil) {
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
        NSString *phoneNumberEncoded = [NSString stringWithUrlEncoding:contact.phoneNumber];
        NSString *messageTextEncoded = [NSString stringWithUrlEncoding:message];
        NSString *sendKeyTextEncoded = [NSString stringWithUrlEncoding:weak_self.accountSendKey];
        
        // create bytes of http post body
        NSString *requestBody = [NSString stringWithFormat:@"phoneNumber=%@&text=%@&_rnr_se=%@", 
                                 phoneNumberEncoded, messageTextEncoded, sendKeyTextEncoded];

        NSString *requestResult = [weak_self rawHttpRequest:@"POST" 
                                                      onURL:SERVICE_SEND_URL 
                                                   withBody:requestBody];
        
        if (requestResult == nil) {
            NSDebug(@"rawHttpRequest failed");
            return;
        }
        
        if ([requestResult isEqualToString:@"{\"ok\":true,\"data\":{\"code\":0}}"]) {
            CKContact *me = [CKContactList sharedInstance].me;
            CKMessage *newMessage = [[CKMessage alloc] initWithContact:me
                                                             timestamp:now 
                                                           messageText:message];
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
        contact = [[CKContact alloc] initWithJabberIdentifier:nil
                                               andDisplayName:contactPhoneNumber
                                               andPhoneNumber:contactPhoneNumber
                                              andContactState:kContactOffline];
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
        [[CKContactList sharedInstance] newMessage:diffMessage forContact:contact];
    }
}

- (void)parseMessagesJSON:(NSData *)jsonResponse andHTML:(NSData *)htmlResponse
{
    NSError *jsonParsingError = nil;
    
    NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:jsonResponse 
                                                                   options:0 
                                                                     error:&jsonParsingError];
    if(jsonParsingError != nil) {
        NSDebug(@"JSON Parsing Error: %@", jsonParsingError);
        return;
    }
    
    // init parser and grab root node of document
    CKXMLParser *htmlParser = [[CKXMLParser alloc] initParserWith:htmlResponse];
    
    // iterate over all threads
    NSDictionary *allThreads = [jsonDictionary objectForKey:@"messages"];
    for (NSString *threadId in allThreads) {
        NSMutableArray *conversation = [[NSMutableArray alloc] init];
        CKContact *contact = [self contactForThread:threadId jsonLookup:jsonDictionary];

        NSString *xpathExpr = [NSString stringWithFormat:
                               @"//div[@id=\'%@\' and @class=\'%@\']//div[@class=\'%@\']",
                               threadId, DIV_ID_NODE_CLASS, DIV_MESSAGE_CLASS];
        NSArray *messageElements = [htmlParser elementsWithXpathExpression:xpathExpr];
        for (CKXMLElement *messageElement in messageElements) {
            // by default set all messages names to other party, on instances of 
            // "Me:", replace with self full name
            CKMessage *message = [[CKMessage alloc] initWithContact:contact];
            
            NSArray *spanElements = [messageElement elementsForName:@"span"];
            for (CKXMLElement *span in spanElements) {
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
    
    // parser cleanup
    [htmlParser parserCleanup];
}



#pragma mark - CKTextMessageService Private Methods

- (BOOL)fetchAccountKeys
{
    // update send key (_rnr_se)
    self.accountSendKey = [self sendKeyRequest];
    if (self.accountSendKey == nil) {
        return NO;
    }
    
    // update refresh key (r)
    self.accountRefreshKey = [self refreshKeyRequest];
    if (self.accountRefreshKey == nil) {
        return NO;
    }
    
    // update account timezone value
    self.accountTimezone = [self timezoneRequest];
    if (self.accountTimezone == nil) {
        return NO;
    }
    
    return YES;
}

- (NSString *)timezoneRequest
{
    if (self.authorizationToken == nil) {
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
    NSUInteger length = range2.location - range1.location - range1.length;
    NSUInteger location = range1.location + range1.length;
    NSRange tzRange = NSMakeRange(location, length);
    
    return [requestResult substringWithRange:tzRange];
}

- (NSString *)sendKeyRequest
{
    NSString *_rnr_se;

    if (self.authorizationToken == nil) {
        return nil;
    }
    
    NSString *requestResult = [self rawHttpRequest:@"GET" onURL:SERVICE_MAIN_PAGE_URL withBody:nil];
    if (requestResult == nil) {
        return nil;
    }
    
    // init parser
    CKXMLParser *htmlParser = [[CKXMLParser alloc] initParserWith:
                               [requestResult dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSArray *inputNodes = [htmlParser elementsWithXpathExpression:@"//input[@name]"];
    CKXMLElement *rnrseElement = nil;
    for (CKXMLElement *inputElement in inputNodes) {
        if ([[[inputElement attributes] objectForKey:@"name"] isEqualToString:@"_rnr_se"]) {
            rnrseElement = inputElement;
            break;
        }
    }
    
    if (rnrseElement == nil) {
        return nil;
    }
    
    _rnr_se = [[NSString alloc] initWithString:[rnrseElement.attributes objectForKey:@"value"]];
    
    // parser cleanup
    [htmlParser parserCleanup];
    
    return _rnr_se;
}

- (NSString *)refreshKeyRequest
{
    if (self.authorizationToken == nil) {
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
    NSUInteger length = range2.location - range1.location - range1.length;
    NSUInteger location = range1.location + range1.length;
    NSRange refreshKeyRange = NSMakeRange(location, length);
    
    return [requestResult substringWithRange:refreshKeyRange];
}

- (void)startFetchUnreadMessagesTimer
{
    timerBlock_t fetchUnreadMessages = ^(void) {
        NSDebug(@"fetching unread messages");

        __weak CKTextMessageService *weak_self = self;

        if (weak_self.authorizationToken == nil) {
            NSDebug(@"fetch failed, no auth token");
            return;
        }
        
        NSString *requestResult = [weak_self rawHttpRequest:@"GET" 
                                                      onURL:SERVICE_UNREAD_INBOX_URL 
                                                   withBody:nil];
        if (requestResult == nil) {
            NSDebug(@"rawHttpRequest result failed in fetch undread, logging out");
            [weak_self.chattaKit logoutOfService];
            return;
        }
    
        NSRange jsonRange1 = [requestResult rangeOfString:@"<json><![CDATA["];
        NSRange jsonRange2 = [requestResult rangeOfString:@"]]></json>"];
        NSUInteger jsonLength = jsonRange2.location - jsonRange1.location - jsonRange1.length;
        NSUInteger jsonLocation = jsonRange1.location + jsonRange1.length;
        NSRange jsonRange = NSMakeRange(jsonLocation, jsonLength);
        NSData *jsonData = [[requestResult substringWithRange:jsonRange] 
                            dataUsingEncoding:NSUTF8StringEncoding];

        NSRange htmlRange1 = [requestResult rangeOfString:@"<html><![CDATA["];
        NSRange htmlRange2 = [requestResult rangeOfString:@"]]></html>"];
        NSUInteger htmlLength = htmlRange2.location - htmlRange1.location - htmlRange1.length;
        NSUInteger htmlLocation = htmlRange1.location + htmlRange1.length;
        NSRange htmlRange = NSMakeRange(htmlLocation, htmlLength);
        NSData *htmlData = [[requestResult substringWithRange:htmlRange] 
                            dataUsingEncoding:NSUTF8StringEncoding];

        [weak_self parseMessagesJSON:jsonData andHTML:htmlData];
    };
    
    fetchUnreadMessagesTimer = [[CKTimer alloc] initWithDispatchTime:1.0 
                                                            interval:30 
                                                               queue:dispatch_queue 
                                                               block:fetchUnreadMessages];
}

- (void)stopFetchUnreadMessagesTimer
{
    [fetchUnreadMessagesTimer invalidate];
}

// check if this method is always called in a queue
- (BOOL)markMessageAsRead:(NSString *)messageIdentification
{
    if (self.authorizationToken == nil) {
        return NO;
    }
    
    NSString *requestBody = [NSString stringWithFormat:@"messages=%@&read=1&_rnr_se=%@", 
                             messageIdentification, self.accountSendKey];
    
    NSString *requestResult = [self rawHttpRequest:@"POST" 
                                             onURL:SERVICE_MARK_MESSAGE_URL 
                                          withBody:requestBody];

    if (requestResult == nil) {
        NSDebug(@"rawHttpRequest failed");
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
                                               cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
                                           timeoutInterval:30];
    
    [httpRequest setHTTPMethod:method];
    [httpRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    if (self.authorizationToken) {
        authString = [NSString stringWithFormat:@"GoogleLogin auth=%@", self.authorizationToken];
        [httpRequest setValue:authString forHTTPHeaderField:@"Authorization"];
    }
    
    if (body) {
        [httpRequest setHTTPBody:[NSData dataWithBytes:body.UTF8String length:body.length]];
    }
    
    
    requestResult = [NSURLConnection sendSynchronousRequest:httpRequest 
                                          returningResponse:&response 
                                                      error:&error];
    
    if (error) {
        NSDebug(@"Connection failed with the following error: %@", error);
        return nil;
    }
    
    return [[NSString alloc] initWithData:requestResult encoding:NSUTF8StringEncoding];
}

@end