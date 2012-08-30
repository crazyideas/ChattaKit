//
//  CKContactMerger.m
//  ChattaKit
//
//  Copyright (c) 2012 CRAZY IDEAS. All rights reserved.
//

#import "CKContactMerger.h"
#import "CKXMLDocument.h"
#import "CKContact.h"
#import "NSString+CKAdditions.h"

#import <AddressBook/AddressBook.h>

@implementation CKContactMerger


- (NSString *)extractPrimaryPhoneNumberForPerson:(ABPerson *)person
{
    NSString *iphoneNumber;
    NSString *mobileNumber;
    NSString *primaryNumber;
    
    ABMultiValue *phoneNumbers = [person valueForProperty:kABPhoneProperty];
    for (int i = 0; i < phoneNumbers.count; i++) {
        NSString *phoneNumberLabel = [phoneNumbers labelAtIndex:i];
        if ([phoneNumberLabel isEqualToString:kABPhoneiPhoneLabel]) {
            iphoneNumber = [phoneNumbers valueAtIndex:i];
        }
        else if ([phoneNumberLabel isEqualToString:kABPhoneMobileLabel]) {
            mobileNumber = [phoneNumbers valueAtIndex:i];
        }
    }
    NSString *primaryPhoneIdentifier = [phoneNumbers primaryIdentifier];
    NSUInteger primaryPhoneIndex = [phoneNumbers indexForIdentifier:primaryPhoneIdentifier];
    primaryNumber = [phoneNumbers valueAtIndex:primaryPhoneIndex];
    
    if (iphoneNumber != nil) {
        primaryNumber = iphoneNumber;
    }
    else if (mobileNumber != nil) {
        primaryNumber = mobileNumber;
    }

    return primaryNumber;
}

- (NSArray *)mostContactedFrom:(CKXMLDocument *)serviceContacts
{
    NSMutableArray *mostContacted = [[NSMutableArray alloc] init];

    ABAddressBook *addressBook = [ABAddressBook sharedAddressBook];
    if (addressBook == nil) {
        return nil;
    }
    
    NSArray *itemElements = [serviceContacts elementsForXpathExpression:@"//*[local-name()='item']"];
    for (CKXMLDocument *item in itemElements) {
        NSString *nameValue = [item.attributes objectForKey:@"name"];
        NSString *jidValue = [item.attributes objectForKey:@"jid"];
        NSString *mcValue = [item.attributes objectForKey:@"mc"];
        NSString *emcValue = [item.attributes objectForKey:@"emc"];
        
        NSInteger mc = (mcValue == nil) ? 0 : mcValue.integerValue;
        NSInteger emc = (emcValue == nil) ? 0 : emcValue.integerValue;
        if (mc < 10 && emc < 10) {
            continue;
        }
        
        CKContact *contactItem = [[CKContact alloc] init];
        contactItem.displayName = [nameValue stringByRemovingWhitespaceNewlineChars];
        contactItem.jabberIdentifier = [jidValue stringByRemovingWhitespaceNewlineChars];
        
        // try finding phone number from first name
        if (contactItem.displayName != nil) {
            ABSearchElement *searchElement;
            
            NSArray *nameComponents = [contactItem.displayName componentsSeparatedByString:@" "];
            // search for first and last name
            if (nameComponents.count > 1) {
                NSString *firstName = [nameComponents objectAtIndex:0];
                NSString *lastName = [nameComponents lastObject];
                ABSearchElement *firstNameSearch = [ABPerson searchElementForProperty:kABFirstNameProperty
                    label:nil key:nil value:firstName comparison:kABPrefixMatchCaseInsensitive];
                ABSearchElement *lastNameSearch = [ABPerson searchElementForProperty:kABLastNameProperty
                    label:nil key:nil value:lastName comparison:kABSuffixMatchCaseInsensitive];
                
                searchElement = [ABSearchElement searchElementForConjunction:kABSearchAnd
                    children:@[ firstNameSearch, lastNameSearch ]];
            }
            // search only first name
            else {
                NSString *firstName = [nameComponents objectAtIndex:0];
                searchElement = [ABPerson searchElementForProperty:kABFirstNameProperty
                    label:nil key:nil value:firstName comparison:kABEqualCaseInsensitive];
            }
            
            NSArray *peopleFound = [addressBook recordsMatchingSearchElement:searchElement];
            if (peopleFound.count > 0) {
                contactItem.phoneNumber =
                    [self extractPrimaryPhoneNumberForPerson:[peopleFound objectAtIndex:0]];
            }
        }
        
        // if we still have not found the phone number, try searching based off the jid
        if (contactItem.phoneNumber == nil && contactItem.jabberIdentifier != nil) {
            ABSearchElement *emailSearch = [ABPerson searchElementForProperty:kABEmailProperty
                label:nil key:nil value:contactItem.jabberIdentifier comparison:kABEqualCaseInsensitive];
            ABSearchElement *imSearch = [ABPerson searchElementForProperty:kABInstantMessageProperty
                label:nil key:kABInstantMessageUsernameKey
                value:contactItem.jabberIdentifier comparison:kABEqualCaseInsensitive];
            ABSearchElement *searchElement = [ABSearchElement searchElementForConjunction:kABSearchAnd
                children:@[ emailSearch, imSearch ]];
            NSArray *peopleFound = [addressBook recordsMatchingSearchElement:searchElement];
            if (peopleFound.count > 0) {
                contactItem.phoneNumber =
                    [self extractPrimaryPhoneNumberForPerson:[peopleFound objectAtIndex:0]];
            }
        }
        
        [mostContacted addObject:contactItem];
    }
    
    return [mostContacted copy];
}

@end
