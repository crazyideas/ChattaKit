//
//  CKContactMerger.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CKXMLDocument;

@interface CKContactMerger : NSObject

- (NSArray *)mostContactedFrom:(CKXMLDocument *)serviceContacts;

@end
