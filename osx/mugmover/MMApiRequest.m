//
//  MMApiRequest.m
//  mugmover
//
//  Created by Bob Fitterman on 1/8/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "NSString+Encode.h"
#import "MMApiRequest.h"

#define DEFAULT_API_TIMEOUT (60.0)
@implementation MMApiRequest


- (id) initUploadForApiVersion: (NSInteger) version
                      bodyData: (NSDictionary *) bodyData // values should NOT be URLEncoded
             completionHandler: (void (^)(NSURLResponse *response,
                                          NSData *data,
                                          NSError *connectionError)) handler
{

    self = [self init];
    if (self)
    {
        NSString *stringUrl = [[NSString alloc] initWithFormat: @"http://localhost:3000/api/v%ld/upload", version];

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

        [NSURLConnection sendAsynchronousRequest: request
                                           queue: [[NSOperationQueue alloc] init]
                               completionHandler: handler];
                                                            
    }
    return self;
}


@end
