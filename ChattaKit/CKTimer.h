//
//  CKTimer.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^timerBlock_t)(void);

@interface CKTimer : NSObject
{
    dispatch_source_t timer;
}

- (id)initWithDispatchTime:(NSTimeInterval)dispatchTime 
                  interval:(NSTimeInterval)interval 
                     queue:(dispatch_queue_t)queue
                     block:(timerBlock_t)block;
- (void)invalidate;

@end
