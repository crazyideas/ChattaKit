//
//  CKXMLParser.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libxml/HTMLparser.h>

@interface CKXMLParser : NSObject
{
    htmlNodePtr rootNode;
}

- (id)initParserWith:(NSData *)html;
- (void)parserCleanup;

- (NSArray *)elementsWithName:(NSString *)elementName;
- (NSArray *)elementsWithXpathExpression:(NSString *)xpathExpression;

@end
