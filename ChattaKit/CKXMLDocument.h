//
//  CKXMLDocument.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <libxml/parser.h>

@interface CKXMLDocument : NSObject
{
    xmlDocPtr xmlDocument;
}

enum {
    CKXMLDocumentTidyHTML = 1 << 0,
    CKXMLDocumentTidyXML  = 1 << 1
};

@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSString *content;
@property (strong, nonatomic) NSArray *elements;
@property (strong, nonatomic) NSArray *xmlns;
@property (strong, nonatomic) NSDictionary *attributes;

- (id)initWithXMLString:(NSString *)string options:(NSUInteger)mask;
- (id)initWithHTMLString:(NSString *)string options:(NSUInteger)mask;

- (BOOL)containsElementsWithName:(NSString *)name;
- (NSArray *)elementsForName:(NSString *)name;
- (NSArray *)elementsForXpathExpression:(NSString *)expression;

@end
