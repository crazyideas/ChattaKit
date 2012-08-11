//
//  CKStanzaLibrary.m
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import "CKStanzaLibrary.h"
#import "NSString+CKAdditions.h"

@implementation CKStanzaLibrary

+ (NSDictionary *)elementLookupDictionary
{
    static NSMutableDictionary *_lookupDict = nil;
    
    if(_lookupDict == nil) { 
        _lookupDict = [[NSMutableDictionary alloc] initWithCapacity:9];
        [_lookupDict setValue:[NSNumber numberWithInt:kStreamStream]    forKey:@"stream:stream"];
        [_lookupDict setValue:[NSNumber numberWithInt:kStreamFeatures]  forKey:@"stream:features"];
        [_lookupDict setValue:[NSNumber numberWithInt:kStreamFeatures]  forKey:@"stream:error"];
        [_lookupDict setValue:[NSNumber numberWithInt:kStanzaAuth]      forKey:@"auth"];
        [_lookupDict setValue:[NSNumber numberWithInt:kStanzaSuccess]   forKey:@"success"];
        [_lookupDict setValue:[NSNumber numberWithInt:kStanzaFailure]   forKey:@"failure"];
        [_lookupDict setValue:[NSNumber numberWithInt:kStanzaInfoQuery] forKey:@"iq"];
        [_lookupDict setValue:[NSNumber numberWithInt:kStanzaPresence]  forKey:@"presence"];
        [_lookupDict setValue:[NSNumber numberWithInt:kStanzaMessage]   forKey:@"message"];
    }
    return [_lookupDict copy];
}

+ (XMLElementType)elementTypeForName:(NSString *)elementName
{
    NSNumber *elementTypeNumber = [[self elementLookupDictionary] valueForKey:elementName];
    if (elementTypeNumber == nil) {
        return kInvalidElementType;
    }
    return [elementTypeNumber intValue];
}

+ (NSData *)startStreamWithDomain:(NSString *)domain
{
    NSString *message = [[NSString alloc] initWithFormat:
                         @"<stream:stream xmlns:stream=\'http://etherx.jabber.org/streams\' "
                         "xmlns=\'jabber:client\' xml:lang=\'en\' "
                         "to=\'%@\' version=\'1.0\'>", domain];
    
    //CKDebug(@"Returning Stanza: %@", message);
    return [message dataUsingEncoding:NSUTF8StringEncoding];
}

+ (NSData *)stopStream
{
    NSString *message = @"</stream:stream>";
    
    //CKDebug(@"Returning SnitWithString:@"</stream:stream>"]tanza: %@", message);
    return [message dataUsingEncoding:NSUTF8StringEncoding];
}

+ (NSData *)authWithUsername:(NSString *)username password:(NSString *)password
{
    NSString *authEncoded = [[NSString stringWithFormat:@"\x00%@\x00%@", 
                              username, password] base64EncodedString];

    NSString *message = [[NSString alloc] initWithFormat:
                         @"<auth xmlns=\'urn:ietf:params:xml:ns:xmpp-sasl\' "
                          "xmlns:ga=\'http://www.google.com/talk/protocol/auth\' " 
                          "ga:client-uses-full-bind-result=\'true\' "
                          "mechanism=\'PLAIN\'>%@</auth>", authEncoded];
    
    //CKDebug(@"Returning Stanza: %@", message);
    return [message dataUsingEncoding:NSUTF8StringEncoding];
}

+ (NSData *)sessionStreamWithJabberIdentifier:(NSString *)jid domain:(NSString *)domain
{
    NSString *message = [[NSString alloc] initWithFormat:
                         @"<stream:stream from=\'%@\' to=\'%@\' version=\'1.0\' "
                          "xml:lang=\'en\' xmlns=\'jabber:client\' "
                          "xmlns:stream=\'http://etherx.jabber.org/streams\'>", 
                          jid, domain];
    
    //CKDebug(@"Returning Stanza: %@", message);
    return [message dataUsingEncoding:NSUTF8StringEncoding];
}

+ (NSData *)infoQueryBindWithRandomIdentifier:(NSString *)identifier
{
    NSString *message = [[NSString alloc] initWithFormat:
                         @"<iq id=\'%@\' type=\'set\'>"
                          "<bind xmlns=\'urn:ietf:params:xml:ns:xmpp-bind\'>"
                         "<resource>chatta</resource></bind></iq>", identifier];
    
    //CKDebug(@"Returning Stanza: %@", message);
    return [message dataUsingEncoding:NSUTF8StringEncoding];
}

+ (NSData *)infoQueryRequestRosterAndPresenceWithJabberIdentifier:(NSString *)jid andIdentifier:(NSString *)identifier
{
    NSString *message = [[NSString alloc] initWithFormat:
                         @"<iq type=\'get\' from=\'%@\' id=\'%@\'>"
                          "<query xmlns=\'jabber:iq:roster\'/></iq>"
                          "<presence/>", jid, identifier];
    
    //CKDebug(@"Returning Stanza: %@", message);
    return [message dataUsingEncoding:NSUTF8StringEncoding];
}

+ (NSData *)presenceProbeFrom:(NSString *)from to:(NSString *)to
{
    NSString *message;
    
    if (from == nil && to == nil) {
        message= @"<presence/>";
    } else {
        message= [[NSString alloc] initWithFormat:
                  @"<presence type=\'probe\' from=\'%@\' to=\'%@\'/>", from, to];
    }
    
    //CKDebug(@"Returning Stanza: %@", message);
    return [message dataUsingEncoding:NSUTF8StringEncoding];
}

+ (NSData *)infoQueryDiscoveryInfoResponseFrom:(NSString *)from andTo:(NSString *)to
{
    NSString *message = [[NSString alloc] initWithFormat:
                         @"<iq type=\'result\' from=\'%@\' to=\'%@\'>"
                         "<identity category=\'client\' type=\'pc\' name=\'chatta\'/>"
                         "<query xmlns='http://jabber.org/protocol/disco#info'>"
                         "<feature var='http://jabber.org/protocol/disco#info'/>"
                         "<feature var='http://jabber.org/protocol/disco#items'/>"
                         "</query></iq>", from, to];
    
    //CKDebug(@"Returning Stanza: %@", message);
    return [message dataUsingEncoding:NSUTF8StringEncoding];
}

+ (NSData *)messageFrom:(NSString *)from to:(NSString *)to withId:(NSString *)identifier andMsg:(NSString *)msg

{
    NSString *message = [[NSString alloc] initWithFormat:
                         @"<message from=\'%@\' id=\'%@\' to=\'%@\' type=\'chat\'>"
                         "<body>%@</body>"
                         "</message>", from, identifier, to, msg];
    
    //CKDebug(@"Returning Stanza: %@", message);
    return [message dataUsingEncoding:NSUTF8StringEncoding];
}

+ (NSData *)presenceType:(NSString *)type to:(NSString *)to
{
    NSString *message = [[NSString alloc] initWithFormat:
                         @"<presence to=\'%@\' type=\'%@\'/>", to, type];
    
    //CKDebug(@"Returning Stanza: %@", message);
    return [message dataUsingEncoding:NSUTF8StringEncoding];
}

+ (NSData *)pingFrom:(NSString *)from withId:(NSString *)identifier
{
    NSString *message = [[NSString alloc] initWithFormat:
                         @"<iq from='%@' to='gmail.com' id='%@' type='get'>"
                          "<ping xmlns='urn:xmpp:ping'/>"
                          "</iq>", from, identifier];
    
    //CKDebug(@"Returning Stanza: %@", message);
    return [message dataUsingEncoding:NSUTF8StringEncoding];            
}



+ (NSString *)cleanupStanza:(NSString *)xmlstring
{
    if (xmlstring == nil) {
        return nil;
    }
    
    NSMutableString *s = [[NSMutableString alloc] initWithString:xmlstring];

    // add a close tags so libxml2 doesn't complain
    if ([s containsString:@"<stream:stream"]) {
        [s appendString:@"</stream:stream>"];
        return [s copy];
    }
    if ([s containsString:@"<stream:error"]) {
        [s appendString:@"</stream:error>"];
        return [s copy];
    }
    
    // weird char that causes libxml2 to crash
    if ([s containsString:@"’"]) {
        return [xmlstring stringByReplacingOccurrencesOfString:@"’" withString:@""];
    }
    
    return xmlstring;
}

@end
