//
//  CKRoster.m
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import "CKRoster.h"

@implementation CKRoster

- (NSArray *)roster
{
    __block NSArray *returnRoster;
    
    if (m_roster == nil) {
        m_roster = nil;
    }
    
    dispatch_sync(m_dispatchQueue, ^(void) {
        returnRoster = [m_roster copy];
    });
    
    return returnRoster;
}

- (id)init
{
    self = [super init];
    if (self) {
        m_dispatchQueue = dispatch_queue_create("roster.queue", NULL);
        m_roster = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)addRosterItem:(CKRosterItem *)rosterItem
{
    dispatch_sync(m_dispatchQueue, ^(void) {
        [m_roster addObject:rosterItem];
    });
}

- (void)removeRosterItem:(CKRosterItem *)rosterItem
{
    dispatch_sync(m_dispatchQueue, ^(void) {
        [m_roster removeObject:rosterItem];
    });
}

- (CKRosterItem *)rosterItemForBareJabberIdentifier:(NSString *)jabberIdentifier
{
    __block CKRosterItem *foundRosterItem;
    
    if (jabberIdentifier == nil) {
        return nil;
    }
    
    dispatch_sync(m_dispatchQueue, ^(void) {
        for (CKRosterItem *rosterItem in m_roster) {
            NSString *bareIdentifier = [[rosterItem.fullJabberIdentifier
                componentsSeparatedByString:@"/"] objectAtIndex:0];
            
            if ([bareIdentifier isEqualToString:jabberIdentifier]) {
                foundRosterItem = rosterItem;
                break;
            }
        }
    });
    
    return foundRosterItem;
}

- (CKRosterItem *)rosterItemForFullJabberIdentifier:(NSString *)jabberIdentifier
{
    __block CKRosterItem *foundRosterItem;
    
    if (jabberIdentifier == nil) {
        return nil;
    }
    
    dispatch_sync(m_dispatchQueue, ^(void) {
        for (CKRosterItem *rosterItem in m_roster) {
            if ([rosterItem.fullJabberIdentifier isEqualToString:jabberIdentifier]) {
                foundRosterItem = rosterItem;
                break;
            }
        }
    });
    
    return foundRosterItem;
}

- (void)dealloc
{
    m_roster = nil;
    if (m_dispatchQueue) {
        dispatch_release(m_dispatchQueue);
    }
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@", self.roster];
}

@end
