//
//  MMNetworkRequest.m
//  mugmover
//
//  Created by Bob Fitterman on 1/9/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMNetworkRequest.h"
#import "MMPhoto.h"

@implementation MMNetworkRequest

#define DEFAULT_HEAD_TIMEOUT (10.0)
#define MAX_RETRIES (5)

extern const NSInteger MMDefaultRetries;

+ (void) getUrlByteLength: (NSString *) urlString
                          photo: (MMPhoto *) photo
{
    NSURL *url = [NSURL URLWithString: urlString];
    NSOperationQueue *tempQueue = [[NSOperationQueue alloc] init];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL: url
                                                           cachePolicy: NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval: DEFAULT_HEAD_TIMEOUT];
    if (!request)
    {
        return;
    }

    // Designate the request a POST request and specify its body data
    [request setHTTPMethod: @"HEAD"];

    __block NSInteger maxRetries = MMDefaultRetries;

    AsyncCompletionHandler headCompletionHandler = ^(NSURLResponse *response, NSData *data, NSError *connectionError)
    {
        if (connectionError)
        {
            DDLogError(@"ERROR      connectionError=%@", connectionError);
            if (maxRetries <= 0)
            {
                DDLogError(@"ERROR      maxRetriesExceeded for %@", request);
            }
            else
            {
                maxRetries = maxRetries - 1;
                [NSURLConnection sendAsynchronousRequest: request
                                                   queue: tempQueue
                                       completionHandler: headCompletionHandler];
            }
        }
        else
        {
            long long filesize = [response expectedContentLength];
            [photo setByteLength: filesize];
        }
        
    };
    [NSURLConnection sendAsynchronousRequest: request
                                       queue: tempQueue
                           completionHandler: headCompletionHandler];
}

@end
