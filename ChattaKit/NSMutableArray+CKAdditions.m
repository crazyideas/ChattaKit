//
//  NSMutableArray+CKAdditions.m
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import "NSMutableArray+CKAdditions.h"

@implementation NSMutableArray (CKAdditions)

- (void)pushStack:(id)object
{
    if (object != nil) {
        [self addObject:object];
    }
}

- (id)popStack
{
    if ([self count] == 0) return nil;
    id lastObject = [self lastObject];
    if (lastObject != nil) {
        [self removeLastObject];
    }
    return lastObject;
}

@end
