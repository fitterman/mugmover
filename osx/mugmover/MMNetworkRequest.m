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


- (id) initMakeHeadRequest: (NSString *) urlString
                  delegate: (MMPhoto *) delegate
{
    
    self = [self init];
    if (self)
    {
        NSURL *url = [NSURL URLWithString: urlString];
        
        _request = [NSMutableURLRequest requestWithURL: url
                                           cachePolicy: NSURLRequestUseProtocolCachePolicy
                                       timeoutInterval: DEFAULT_HEAD_TIMEOUT];
        if (!_request)
        {
            return nil;
        }
        
        // Designate the request a POST request and specify its body data
        [_request setHTTPMethod: @"HEAD"];
        
        _receivedData = [NSMutableData dataWithCapacity: 0];
        
        // create the connection, starting the request
        _connection = [[NSURLConnection alloc] initWithRequest: _request
                                                      delegate: self];

        if (!_connection)
        {
            [self releaseStrongPointers];
            return nil;
        }
        _delegate = delegate;
        _retries = MAX_RETRIES;
    }
    return self;
}

- (void) connection: (NSURLConnection *) connection
 didReceiveResponse: (NSURLResponse *) response
{
    long long filesize = [response expectedContentLength];
    NSLog(@"FILESIZE %lld", filesize);
    [_delegate setByteLength: filesize];
    [self releaseStrongPointers];
}

- (BOOL) retryable
{
    if (_retries > 0)
    {
        _retries--;
        _connection = [[NSURLConnection alloc] initWithRequest: _request
                                                      delegate: self];
        if (!_connection)
        {
            _request = nil;
            return NO;
        }
        return YES;
    }
    return NO;
    
}

- (void) connection: (NSURLConnection *) connection
   didFailWithError: (NSError *) error
{
    // Release the connection and the data object.
    
    [_delegate mmNetworkRequest: self
               didFailWithError: error];
    [self releaseStrongPointers];
}

- (void) releaseStrongPointers
{
    _connection = nil;
    _delegate = nil;
    _receivedData = nil;
    _request = nil;
}

@end
