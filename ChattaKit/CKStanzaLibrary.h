//
//  CKStanzaLibrary.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CKStanzaLibrary : NSObject

// lookup dict static methods
+ (NSDictionary *)elementLookupDictionary;
+ (XMLElementType)elementTypeForName:(NSString *)elementName;

// return pre-formatted stanza bytes for messages static methods
+ (NSData *)startStreamWithDomain:(NSString *)domain;
+ (NSData *)stopStream;
+ (NSData *)authWithUsername:(NSString *)username password:(NSString *)password;
+ (NSData *)sessionStreamWithJabberIdentifier:(NSString *)jid domain:(NSString *)domain;
+ (NSData *)infoQueryBindWithRandomIdentifier:(NSString *)identifier;
+ (NSData *)infoQueryRequestRosterAndPresenceWithJabberIdentifier:(NSString *)jid andIdentifier:(NSString *)identifier;
+ (NSData *)infoQueryDiscoveryInfoResponseFrom:(NSString *)from andTo:(NSString *)to;
+ (NSData *)messageFrom:(NSString *)from to:(NSString *)to withId:(NSString *)identifier andMsg:(NSString *)msg;
+ (NSData *)presenceProbeFrom:(NSString *)from to:(NSString *)to;
+ (NSData *)presenceType:(NSString *)type to:(NSString *)to;
+ (NSData *)pingFrom:(NSString *)from withId:(NSString *)identifier;

@end
