//
//  CKTidyDocument.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CKTidy : NSObject

+ (NSString *)tidyXMLString:(NSString *)string options:(NSUInteger)mask;

@end
