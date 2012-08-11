//
//  CKXMLElement.m
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import "CKXMLElement.h"
#import "CKStanzaLibrary.h"
#import "NSString+CKAdditions.h"

@implementation CKXMLElement

@synthesize name = _name;
@synthesize attributes = _attributes;
@synthesize content = _content;
@synthesize elements = _elements;
@synthesize xmlns = _xmlns;

-(id)initWithNode:(xmlNode *)node
{
	if (self = [super init]) {
        if (node != NULL && node->type == XML_ELEMENT_NODE) {
            // extract name
            _name = [NSString stringWithCString:(char *)node->name 
                                       encoding:NSUTF8StringEncoding];
            
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
            _xmlns = [tmp_ns copy];
            
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
            _attributes = [tmp_dict copy];
            
            // extract children
            NSMutableArray *tmp_array = [[NSMutableArray alloc] init];
            for (xmlNode *child = node->children; child != NULL; child = child->next) {
                if (child->type == XML_ELEMENT_NODE) {
                    [tmp_array addObject:[[CKXMLElement alloc] initWithNode:child]];
                }
            }
            _elements = [tmp_array copy];
            
            // extract content
            if (node->children != NULL && node->children->content != NULL) {
                _content = [NSString stringWithCString:(char *)node->children->content 
                                              encoding:NSUTF8StringEncoding];
            }
        }
	}
	return self;
}

- (id)initWithXMLString:(NSString *)string
{
    self = [super init];
    if (self) {
        const char *content = [string cStringUsingEncoding:NSUTF8StringEncoding];
        int length = (int)[string length];
        
        xmlDocPtr doc = xmlReadMemory(content, length, "noname.xml", NULL, 0);
        if (doc == NULL) {
            CKDebug(@"[-] xmlReadMemory returned NULL");
            return nil;
        }
        
        self = [[CKXMLElement alloc] initWithNode:doc->children];
        
        xmlFreeDoc(doc);
        xmlCleanupParser();
    }
    
    return self;
}

- (id)initWithXMLString:(NSString *)string appendingNamespace:(NSString *)xmlns
{
    NSError *error = nil;
    NSString *nsstring = nil;
    NSRegularExpression *regex = nil;
    NSTextCheckingResult *match = nil;
    
    regex = [NSRegularExpression regularExpressionWithPattern:@"[\\w]+:[\\w]+" 
                                                      options:NSRegularExpressionSearch 
                                                        error:&error];
    match = [regex firstMatchInString:string 
                              options:0 
                                range:NSMakeRange(0, [string length])];
    
    if (match != nil) {
        NSRange matchRange = [match range];
        NSString *matchString = [string substringWithRange:matchRange];
        NSString *replacement = [NSString stringWithFormat:@"%@ %@", matchString, xmlns];
        nsstring = [string stringByReplacingOccurrencesOfString:matchString 
                                                     withString:replacement 
                                                        options:0 
                                                          range:matchRange];
    }
    
    return [self initWithXMLString:[nsstring copy]];
}

- (NSArray *)elementsForName:(NSString *)name
{
    NSMutableArray *tmp = [[NSMutableArray alloc] init];
    for (CKXMLElement *element in self.elements) {
        if ([element.name isEqualToString:name]) {
            [tmp addObject:element];
        }
    }
    if (tmp.count > 0) {
        return [tmp copy];
    }
    return nil;
}

- (BOOL)containsElementsWithName:(NSString *)name
{
    for (CKXMLElement *element in self.elements) {
        if ([element.name isEqualToString:name]) {
            return YES;
        }
    }
    return NO;
}

- (NSString *)xmlnsWithPrefix:(NSString *)prefix
{
    for (NSString *ns in self.xmlns) {
        if ([ns containsString:[NSString stringWithFormat:@"xmlns:%@", prefix]]) {
            return ns;
        }
    }
    return nil;
}

- (NSString *)description
{
    return [NSString stringWithFormat:
            @"name: %@, content: %@, attributes: %@, elements: %@, xmlns: %@", 
            self.name, self.content, self.attributes, self.elements, self.xmlns];
}

@end
