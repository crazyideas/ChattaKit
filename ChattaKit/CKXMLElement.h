//
//  CKXMLElement.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <libxml/parser.h>

@interface CKXMLElement : NSObject

@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSDictionary *attributes;
@property (strong, nonatomic) NSArray *elements;
@property (strong, nonatomic) NSString *content;
@property (strong, nonatomic) NSArray *xmlns;

- (id)initWithNode:(xmlNode *)node;
- (id)initWithXMLString:(NSString *)string;
- (id)initWithXMLString:(NSString *)string appendingNamespace:(NSString *)xmlns;

- (NSArray *)elementsForName:(NSString *)name;
- (BOOL)containsElementsWithName:(NSString *)name;
- (NSString *)xmlnsWithPrefix:(NSString *)prefix;

@end
