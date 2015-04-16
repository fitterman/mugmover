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

/**
 * Takes in a string and encodes several characters that would otherwise not be encoded.
 * (Derived from http://stackoverflow.com/questions/8088473/url-encode-an-nsstring)
 */
+ (NSString *) percentEncodeAlmostEverything:(NSString *)inString
{
    NSMutableString *output = [NSMutableString string];
    const unsigned char *source = (const unsigned char *)[inString UTF8String];
    NSInteger sourceLen = strlen((const char *)source);
    for (int i = 0; i < sourceLen; ++i)
    {
        // While it is possible to expand the list of characters, it ends up being more
        // run-time testing. Including some basic characters leaves it readable and keeps
        // it getting too large.
        const unsigned char thisChar = source[i];
        if ((thisChar == ' ') ||
            (thisChar >= 'a' && thisChar <= 'z') ||
            (thisChar >= 'A' && thisChar <= 'Z') ||
            (thisChar >= '0' && thisChar <= '9'))
        {
            [output appendFormat:@"%c", thisChar];
        }
        else
        {
            [output appendFormat:@"%%%02X", thisChar];
        }
    }
    return output;
}
@end
