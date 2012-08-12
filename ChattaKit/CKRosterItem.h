//
//  CKRosterItem.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CKRosterItem : NSObject

@property (nonatomic, strong) NSString *fullJabberIdentifier;
@property (nonatomic, strong) NSString *bareJabberIdentifier;
@property (nonatomic, strong) NSString *status;
@property (nonatomic, strong) NSString *show;
@property (nonatomic, strong) NSData *photo;
@property (nonatomic) BOOL online;

@end
