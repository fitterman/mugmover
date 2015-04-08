//
//  MMDataUtility.m
//  mugmover
//
//  Created by Bob Fitterman on 4/1/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMDataUtility.h"

@implementation MMDataUtility

/**
 This method ingests an NSData object that is expected to contain UTF-8 JSON-encoded Object.
 If it is successful, it returns the parsed data, which should always be an NSDictionary.
 If valid JSON is parsed and it is not a JSON Object (e.g., Array), nil will be returned.
 */
+ (NSDictionary *) parseJsonData: (NSData *) data
{
    if (data && ([data length] > 0))
    {
        NSError *jsonParsingError = nil;
        NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData: data
                                                                   options: 0
                                                                     error: &jsonParsingError];
        if (jsonParsingError)
        {
            NSString *formattedString = [[NSString alloc] initWithData: data
                                                              encoding: NSASCIIStringEncoding];
            NSInteger strLen = [formattedString length];
            if (strLen > 60)
            {
                formattedString = [NSString stringWithFormat: @"%@...", [formattedString substringToIndex: 60]];
            }
            DDLogError(@"ERROR         Malformed JSON %@ (%ld bytes)", formattedString, strLen);
        }
        else
        {
            if([dictionary isKindOfClass:[NSDictionary class]])
            {
                return dictionary;
            }
            else
            {
                DDLogInfo(@"ERROR         Valid JSON, but not an Object. Ignored.");
            }
        }
    }
    else
    {
        DDLogError(@"ERROR         No data received");
    }
    return nil;
}

@end
