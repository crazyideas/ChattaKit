//
//  CKXMLParser.m
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import "CKXMLParser.h"
#import "CKXMLElement.h"
#import "NSMutableArray+CKAdditions.h"

#import <libxml/tree.h>
#import <libxml/parser.h>
#import <libxml/xpath.h>
#import <libxml/xpathInternals.h>


@implementation CKXMLParser

- (id)initParserWith:(NSData *)html {
    self = [super init];
    if (self) {
        if (html == nil) {
            return nil;
        }
        
        xmlInitParser();
        
        CFStringEncoding cfstrenc = CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding);
        CFStringRef cfstrref = CFStringConvertEncodingToIANACharSetName(cfstrenc);
        const char *encoding = CFStringGetCStringPtr(cfstrref, 0);
        
        rootNode = (xmlNodePtr)htmlReadDoc((xmlChar *)[html bytes], nil, encoding, 
                                           XML_PARSE_NOERROR | XML_PARSE_NOWARNING);
    }
    return self;
}

- (void)parserCleanup
{
    if (rootNode) {
        xmlFreeDoc((htmlDocPtr) rootNode);
        rootNode = NULL;
        
        xmlCleanupParser();
    }
}

- (void)dealloc
{
    [self parserCleanup];
}

- (NSArray *)elementsWithName:(NSString *)nodeName
{
    return [self elementsWithXpathExpression:[NSString stringWithFormat:@"//%@", nodeName]];
}

- (NSArray *)elementsWithXpathExpression:(NSString *)xpathExpression
{
    size_t i, size;
    xmlNodeSetPtr nodes;
    xmlXPathObjectPtr xpathObj;
    xmlXPathContextPtr xpathCtx;
    
    xpathCtx = xmlXPathNewContext((xmlDocPtr)rootNode);
    if(xpathCtx == NULL) {
        CKDebug(@"[-] unable to create xpath context");
        return nil;
    }
    
    const char *xpathExpr = xpathExpression.UTF8String;
    
    xpathObj = xmlXPathEvalExpression((xmlChar *)xpathExpr, xpathCtx);
    if(xpathObj == NULL) {
        CKDebug(@"[-] unable to evaluate xpath expression");
        return nil;
    }
    
    nodes = xpathObj->nodesetval;
    size = (nodes) ? nodes->nodeNr : 0;
    
    NSMutableArray *matchingNodes = [[NSMutableArray alloc] initWithCapacity:size];
    
    for (i = 0; i < size; i++) {
        if (nodes->nodeTab[i]->type == XML_ELEMENT_NODE) {
            [matchingNodes addObject:[[CKXMLElement alloc] initWithNode:nodes->nodeTab[i]]];
        }
    }
    
    xmlXPathFreeObject(xpathObj);
    xmlXPathFreeContext(xpathCtx); 
    
    return [matchingNodes copy];
}

@end
