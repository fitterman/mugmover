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
 This method ingests an NSData object that is expected to contain UTF-8 JSON-encoded data.
 If it is successful, it returns the parsed data, which should always be an NSDictionary.
 No attempt is made to validate that assumption in this routine. If an error occurs, it is
 logged and nil is returned.
 */
+ (NSDictionary *) parseJsonData: (NSData *)data
{
    if ([data length] > 0)
    {
        NSError *jsonParsingError = nil;
        NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData: data
                                                                   options: 0
                                                                     error: &jsonParsingError];
        if (jsonParsingError)
        {
            DDLogError(@"ERROR      malformed JSON");
            DDLogError(@"%@", [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding]);
        }
        else
        {
            return dictionary;
        }
    }
    else
    {
        DDLogError(@"ERROR      No data received");
    }
    return nil;
}


@end
