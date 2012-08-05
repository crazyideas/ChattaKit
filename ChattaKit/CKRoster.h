//
//  CKRoster.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CKRosterItem.h"

@interface CKRoster : NSObject
{
    NSMutableArray *m_roster;
    dispatch_queue_t m_dispatchQueue;
}

@property (nonatomic, strong, readonly) NSArray *roster;

- (void)addRosterItem:(CKRosterItem *)rosterItem;
- (void)removeRosterItem:(CKRosterItem *)rosterItem;

- (CKRosterItem *)rosterItemForBareJabberIdentifier:(NSString *)jabberIdentifier;
- (CKRosterItem *)rosterItemForFullJabberIdentifier:(NSString *)jabberIdentifier;

@end
