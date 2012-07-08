//
//  NSMutableArray+CKAdditions.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libxml/HTMLparser.h>
#import "CKXMLElement.h"

@interface NSMutableArray (CKAdditions)

- (void)pushStack:(id)object;
- (id)popStack;

@end
