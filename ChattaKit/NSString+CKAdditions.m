//
//  NSString+CKAdditions.m
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import "NSString+CKAdditions.h"
#import "base64.h"

@implementation NSString (CKAdditions)

- (BOOL)containsString:(NSString *)string
{
    return [self rangeOfString:string].location != NSNotFound;
}

- (NSString *)base64EncodedString
{
    // convert nsstring to c string
    const char *source = [self cStringUsingEncoding:NSUTF8StringEncoding];
    size_t source_len = [self length];
    
    // get the length of the destination string (includes null 
    // terminator) and malloc memory
    size_t destination_len = Base64encode_len(source_len);
    char *destination = malloc(destination_len);
    if (destination == NULL) {
        return nil;
    }
    
    // encode string
    Base64encode(destination, source, (int)source_len);
    
    // convert c string to nsstring
    NSString *encodedString = [NSString stringWithCString:destination 
                                                 encoding:NSUTF8StringEncoding];
    
    // free up memory
    free(destination);
    destination = NULL;
    
    // return encoded nsstring
    return encodedString;
}

- (NSString *)base64DecodedString
{
    const char *source = [self cStringUsingEncoding:NSUTF8StringEncoding];
    
    // get the length of the destination string (includes null 
    // terminator) and malloc memory
    size_t destination_len = Base64decode_len(source);
    char *destination = malloc(destination_len);
    if (destination == NULL) {
        return nil;
    }
    
    // decode string
    Base64decode(destination, source);
    
    // convert c string to nsstring
    NSString *decodedString = [NSString stringWithCString:destination 
                                                 encoding:NSUTF8StringEncoding];
    
    // free up memory
    free(destination);
    destination = NULL;
    
    // return encoded nsstring
    return decodedString;
}

- (NSString *) stringByRemovingWhitespaceNewlineChars
{
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

+ (NSString *)stringByStrippingTag:(NSString *)name fromXMLString:(NSString *)string
{
    // start element range
    NSRange elementStart = [string rangeOfString:[NSString stringWithFormat:@"<%@", name]];
    NSRange startRange = NSMakeRange(0, elementStart.location);
    if (elementStart.location == NSNotFound) {
        return string;
    }
    
    // end element range
    NSRange elementEnd = [string rangeOfString:[NSString stringWithFormat:@"</%@>", name]];
    NSUInteger end_location = elementEnd.location + (name.length + 3);
    NSRange endRange = NSMakeRange(end_location, string.length - end_location);
    if (endRange.location == NSNotFound) {
        return string;
    }
    
    // return stripped string
    return [NSString stringWithFormat:@"%@%@", 
            [string substringWithRange:startRange], 
            [string substringWithRange:endRange]];
}

+ (NSString *)randomStringWithLength:(NSUInteger)length
{
    srand((unsigned int)time(NULL));
    char *s = malloc(sizeof(char) * length);
    if (s == NULL) {
        return nil;
    }
    
    static const char alphanum[] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    for (size_t i = 0; i < length; i++) {
        *(s + i) = alphanum[rand() % (sizeof(alphanum) - 1)];
    }
    s[length] = '\0';
    
    NSString *randomString = [NSString stringWithCString:s encoding:NSUTF8StringEncoding];
    
    // free up resources allocated
    if (s) {
        free(s);
        s = NULL;
    }
    return randomString;
}

+ (NSString *)stringWithUrlEncoding:(NSString *)string
{
    return [string stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];
}


@end
