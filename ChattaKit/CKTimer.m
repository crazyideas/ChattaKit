//
//  CKTimer.m
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import "CKTimer.h"

@implementation CKTimer

- (id)initWithDispatchTime:(NSTimeInterval)dispatchTime 
                  interval:(NSTimeInterval)interval 
                     queue:(dispatch_queue_t)queue
                     block:(timerBlock_t)block
{
    self = [super init];
    if (self) {
        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        if (timer != NULL) {
            dispatch_source_set_timer(timer, 
                                      dispatch_time(DISPATCH_TIME_NOW, dispatchTime * NSEC_PER_SEC), 
                                      interval * NSEC_PER_SEC, 
                                      0);
            dispatch_source_set_event_handler(timer, block);
            dispatch_resume(timer);
            
        }
    }
    return self;
}

- (void)invalidate
{
    if (timer) {
        dispatch_source_cancel(timer);
    }
}

- (void)dealloc
{
    if (timer) {
        dispatch_source_cancel(timer);
        dispatch_release(timer);
    }
}

@end
