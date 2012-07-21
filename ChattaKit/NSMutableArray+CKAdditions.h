//
//  NSMutableArray+CKAdditions.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableArray (CKAdditions)

- (void)pushStack:(id)object;
- (id)popStack;

- (void)pushQueue:(id)object;
- (id)popQueue;

@end
