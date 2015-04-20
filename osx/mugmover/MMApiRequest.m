//
//  MMApiRequest.m
//  mugmover
//
//  Created by Bob Fitterman on 1/8/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "NSString+Encode.h"
#import "MMApiRequest.h"
#import "MMDataUtility.h"

#define DEFAULT_API_TIMEOUT (60.0)
const NSInteger apiVersion = 1;
extern NSInteger const MMDefaultRetries;

@implementation MMApiRequest

+ (BOOL) synchronousUpload: (NSDictionary *) bodyData // values should NOT be URLEncoded
         completionHandler: (ServiceResponseHandler) serviceResponseHandler
{
    NSString *stringUrl = [[NSString alloc] initWithFormat: @"http://localhost:3000/api/v%ld/upload", apiVersion];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL: [NSURL URLWithString: stringUrl]];
    [request setCachePolicy: NSURLRequestReloadIgnoringLocalCacheData]; // Cache doesn't matter as it's all POSTs of uploads.
    [request setTimeoutInterval: DEFAULT_API_TIMEOUT];

    // If bodyData is passed in, then turn this into a POST request
    if (bodyData)
    {
        // Set the request's content type to application/x-www-form-urlencoded
        [request setValue: @"application/x-www-form-urlencoded" forHTTPHeaderField: @"Content-Type"];

        // Designate the request a POST request and specify its body data
        [request setHTTPMethod: @"POST"];
        [request setValue: @"application/json" forHTTPHeaderField: @"Accept"];

        // URL-encode the data and then send that

        NSMutableArray *encodedValues = [[NSMutableArray alloc] initWithCapacity: [bodyData count]];
        for(id key in bodyData)
        {
            NSString *value = [bodyData objectForKey: key];
            NSString *encodedBodyData = [NSString stringWithFormat: @"%@=%@", @"data", [value encodeString: NSUTF8StringEncoding]];
            [encodedValues addObject: encodedBodyData];
        }
        NSString *postData = [encodedValues componentsJoinedByString: @"&"];
        [request setHTTPBody: [NSData dataWithBytes: [postData UTF8String]
                                             length: strlen([postData UTF8String])]];
    }

    
    NSURLResponse *response;
    NSError *connectionError;
    NSInteger retries = MMDefaultRetries;
    while (retries-- > 0)
    {
        NSData *serverData = [NSURLConnection sendSynchronousRequest: request
                                                   returningResponse: &response
                                                               error: &connectionError];
        if (connectionError)
        {
            DDLogError(@"ERROR      connectionError=%@", connectionError);
            // TODO BE SURE YOU CHECK FOR AN AUTH ERROR AND DO NO RETRY ON AN AUTH ERROR
            continue;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if ([httpResponse statusCode] >= 400) // These are errors (300 is handled automatically)
        {
            DDLogError(@"ERROR      httpError=%ld", (long)[httpResponse statusCode]);
            if ([serverData length] > 0)
            {
                NSString *s = [[NSString alloc] initWithData: serverData encoding: NSUTF8StringEncoding];
                DDLogError(@"response=%@", s);
            }
            if ([httpResponse statusCode] >= 500)
            {
                continue;   // Worthy of a retry
            }
            else
            {
                return NO; // No sense in retrying this as it will not change
            }
        }
        NSDictionary *parsedJsonData = [MMDataUtility parseJsonData: serverData];
        if (parsedJsonData)
        {
            serviceResponseHandler(parsedJsonData);
            return YES;
        }
    }
    DDLogError(@"ERROR      maxRetriesExceeded for %@", request);
    return NO;
}


@end
