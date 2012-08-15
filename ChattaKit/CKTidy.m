//
//  CKTidyDocument.h
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import "CKTidy.h"
#import "CKXMLDocument.h"
#include <tidy/buffio.h>
#include <tidy/tidy.h>

@implementation CKTidy

+ (NSString *)tidyXMLString:(NSString *)string options:(NSUInteger)mask
{
    int err;
    
    TidyDoc tidyDocument;    
    TidyBuffer tidyOutputBuffer = { 0 };

    tidyDocument = tidyCreate();
    tidyOptSetBool(tidyDocument, TidyShowWarnings, no);
    tidyOptSetInt(tidyDocument, TidyShowErrors, 0);
    tidyOptSetBool(tidyDocument, TidyForceOutput, yes);
    if ((mask & CKXMLDocumentTidyXML) == CKXMLDocumentTidyXML) {
        tidyOptSetBool(tidyDocument, TidyXmlTags, yes);
        tidyOptSetBool(tidyDocument, TidyXmlOut, yes);
    }

    const char *xmlString = [string UTF8String];
    
    err = tidyParseString(tidyDocument, xmlString);
    if (err < 0) {
        CKDebug(@"[-] (tidy) unable to parse string: %s", xmlString);
        return nil;
    }
    
    err = tidyCleanAndRepair(tidyDocument);
    if (err < 0) {
        CKDebug(@"[-] (tidy) unable to clean and repair document");
        return nil;
    }
    
    err = tidySaveBuffer(tidyDocument, &tidyOutputBuffer);
    if (err < 0) {
        CKDebug(@"[-] (tidy) unable to save buffer");
        return nil;
    }
    
    NSString *outputXmlString = [[NSString alloc] initWithCString:
        (const char *)tidyOutputBuffer.bp encoding:NSUTF8StringEncoding];
    
    tidyBufFree(&tidyOutputBuffer);
    tidyRelease(tidyDocument);
    
    return outputXmlString;
}

@end
