//
//  CKXMLDocument.m
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import "CKTidy.h"
#import "CKXMLDocument.h"
#import "NSString+CKAdditions.h"

#import <libxml/tree.h>
#import <libxml/xpath.h>
#import <libxml/parser.h>
#import <libxml/HTMLparser.h>
#import <libxml/xpathInternals.h>

@implementation CKXMLDocument

-(id)initWithNode:(xmlNode *)node
{
    self = [super init];
    if (self) {
        [self parseXMLElement:node];
    }
    return self;
}

- (void)parseXMLElement:(xmlNode *)node
{
    if (node != NULL && node->type == XML_ELEMENT_NODE) {
        // extract name
        self.name = [NSString stringWithCString:(char *)node->name encoding:NSUTF8StringEncoding];
        
        // extract content
        if (node->children != NULL && node->children->content != NULL) {
            self.content = [NSString stringWithCString:
                (char *)node->children->content encoding:NSUTF8StringEncoding];
        }
        
        // extract xmlns
        NSMutableArray *tmp_ns = [[NSMutableArray alloc] init];
        for (xmlNs *ns = node->ns; ns != NULL; ns = ns->next) {
            if (ns->prefix != NULL) {
                [tmp_ns addObject:[NSString stringWithFormat:
                    @"xmlns:%s=\'%s\'", ns->prefix, ns->href]];
            } else {
                [tmp_ns addObject:[NSString stringWithFormat:
                    @"xmlns=\'%s\'", ns->href]];
            }
        }
        self.xmlns = [tmp_ns copy];
        
        // extract attributes
        NSMutableDictionary *tmp_dict = [[NSMutableDictionary alloc] init];
        for (xmlAttr *attr = node->properties; attr != NULL; attr = attr->next) {
            if (attr->type == XML_ATTRIBUTE_NODE) {
                xmlChar *attr_value = xmlGetProp(node, attr->name);
                if (attr_value != NULL) {
                    [tmp_dict setObject:[NSString stringWithCString:(char *)attr_value
                                                           encoding:NSUTF8StringEncoding]
                                 forKey:[NSString stringWithCString:(char *)attr->name
                                                           encoding:NSUTF8StringEncoding]];
                    xmlFree(attr_value);
                    attr_value = NULL;
                }
            }
        }
        self.attributes = (tmp_dict.count > 0) ? [tmp_dict copy] : nil;
        
        // extract children
        NSMutableArray *tmp_array = [[NSMutableArray alloc] init];
        for (xmlNode *child = node->children; child != NULL; child = child->next) {
            if (child->type == XML_ELEMENT_NODE) {
                [tmp_array addObject:[[CKXMLDocument alloc] initWithNode:child]];
            }
        }
        self.elements = (tmp_array.count > 0) ? [tmp_array copy] : nil;
    }
}


- (id)initWithXMLString:(NSString *)string options:(NSUInteger)mask
{
    self = [super init];
    if (self) {
        // use tidy to cleanup xml string
        NSString *tidyString = [CKTidy tidyXMLString:string options:mask];
        if (tidyString == nil) {
            CKDebug(@"[-] (ckxmldocument) unable to tidy xml string: %@", string);
        }
        
        // silence error logging
        initGenericErrorDefaultFunc(NULL);
        xmlSetStructuredErrorFunc(NULL, NULL);
        
        const char *xmlString = [tidyString UTF8String];
        int xmlStringSize = (int)tidyString.length;
        const char *encoding = [NSString encodingBufferWithEncoding:NSUTF8StringEncoding];
        int xmlOptionsMask = XML_PARSE_RECOVER | XML_PARSE_NOERROR | XML_PARSE_NOWARNING;
        
        // parse xml in-memory and build tree
        xmlDocument = xmlReadMemory(xmlString, xmlStringSize, "", encoding, xmlOptionsMask);
        if (xmlDocument == NULL) {
            CKDebug(@"[-] (ckxmldocument) unable to read xml string: %s", xmlString);
            return nil;
        }
        
        // parse node
        [self parseXMLElement:xmlDocument->children];
    }
    return self;
}

- (id)initWithHTMLString:(NSString *)string options:(NSUInteger)mask
{
    self = [super init];
    if (self) {
        // use tidy to cleanup xml string
        NSString *tidyString = [CKTidy tidyXMLString:string options:mask];
        if (tidyString == nil) {
            CKDebug(@"[-] (ckxmldocument) unable to tidy xml string: %@", string);
        }
        
        // silence error logging
        initGenericErrorDefaultFunc(NULL);
        xmlSetStructuredErrorFunc(NULL, NULL);
        
        const char *xmlString = [tidyString UTF8String];
        const char *encoding = [NSString encodingBufferWithEncoding:NSUTF8StringEncoding];
        int htmlOptionsMask = HTML_PARSE_RECOVER | HTML_PARSE_NOERROR | HTML_PARSE_NOWARNING;

        // parse xml in-memory and build tree
        xmlDocument = htmlReadDoc((const xmlChar *)xmlString, NULL, encoding, htmlOptionsMask);
        if (xmlDocument == NULL) {
            CKDebug(@"[-] (ckxmldocument) unable to read xml string: %s", xmlString);
            return nil;
        }
    }
    return self;
}

- (void)dealloc
{
    if (xmlDocument) {
        xmlFreeDoc(xmlDocument);
        xmlDocument = NULL;
    }
    xmlCleanupParser();
}

- (BOOL)containsElementsWithName:(NSString *)name
{
    for (CKXMLDocument *element in self.elements) {
        if ([element.name isEqualToString:name]) {
            return YES;
        }
    }
    return NO;
}

- (NSArray *)elementsForName:(NSString *)name
{
    NSMutableArray *tmp = [[NSMutableArray alloc] init];
    for (CKXMLDocument *element in self.elements) {
        if ([element.name isEqualToString:name]) {
            [tmp addObject:element];
        }
    }
    return (tmp.count > 0) ? [tmp copy] : nil;
}

- (NSArray *)elementsForXpathExpression:(NSString *)expression
{
    size_t i, size;
    xmlNodeSetPtr nodes;
    xmlXPathObjectPtr xpathObj;
    xmlXPathContextPtr xpathCtx;
    
    xpathCtx = xmlXPathNewContext((xmlDocPtr)xmlDocument);
    if(xpathCtx == NULL) {
        CKDebug(@"[-] unable to create xpath context");
        return nil;
    }
    
    const char *xpathExpr = expression.UTF8String;
    
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
            [matchingNodes addObject:[[CKXMLDocument alloc] initWithNode:nodes->nodeTab[i]]];
        }
    }
    
    xmlXPathFreeObject(xpathObj);
    xmlXPathFreeContext(xpathCtx);
    
    return (matchingNodes.count > 0) ? [matchingNodes copy] : nil;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"name: %@, content: %@, attributes: %@, elements: %@",
            self.name, self.content, self.attributes, self.elements];
}

@end
