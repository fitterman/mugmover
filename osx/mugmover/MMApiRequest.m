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
                      bodyData: (NSDictionary *)bodyData // values should NOT be URLEncoded
{
    
    self = [self init];
    if (self)
    {
        NSString *stringUrl = [[NSString alloc] initWithFormat:@"http://localhost:3000/api/v%ld/upload", version];

        _request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString: stringUrl]];
        [_request setCachePolicy: NSURLRequestUseProtocolCachePolicy];
        [_request setTimeoutInterval: DEFAULT_API_TIMEOUT];

        // If bodyData is passed in, then turn this into a POST request
        if (bodyData)
        {
            // Set the request's content type to application/x-www-form-urlencoded
            [_request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
            
            // Designate the request a POST request and specify its body data
            [_request setHTTPMethod: @"POST"];
            [_request setValue: @"application/json" forHTTPHeaderField: @"Accept"];
            
            // URL-encode the data and then send that
            
            NSMutableArray *encodedValues = [[NSMutableArray alloc] initWithCapacity: [bodyData count]];
            for(id key in bodyData)
            {
                NSString *value = [bodyData objectForKey: key];
                NSString *encodedBodyData = [NSString stringWithFormat: @"%@=%@", @"data", [value encodeString: NSUTF8StringEncoding]];
                [encodedValues addObject: encodedBodyData];
            }
            NSString *postData = [encodedValues componentsJoinedByString: @"&"];
            [_request setHTTPBody: [NSData dataWithBytes: [postData UTF8String]
                                                 length: strlen([postData UTF8String])]];
        }

        _receivedData = [NSMutableData dataWithCapacity: 0];

        // create the connection, starting the request
        _connection = [[NSURLConnection alloc] initWithRequest: _request
                                                      delegate: self];
        if (!_connection)
        {
            _receivedData = nil; // Release the receivedData object.
            return nil;
        }
    }
    return self;
}

- (void)connection: (NSURLConnection *) connection
didReceiveResponse: (NSURLResponse *) response
{
    // This method is called when the server has determined that it
    // has enough information to create the NSURLResponse object.
    // It can be called multiple times, for example in the case of a
    // redirect, so each time we reset the data.
    
    [_receivedData setLength: 0];
}

- (void)connection: (NSURLConnection *) connection
    didReceiveData: (NSData *) data
{
    // Append the new data to what you have already.
    [_receivedData appendData: data];
}

- (void)connection: (NSURLConnection *) connection
  didFailWithError: (NSError *) error
{
    // Release the connection and the data object.

    _connection = nil;
    _receivedData = nil;
    
    // inform the user
    NSLog(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
}

- (void)connectionDidFinishLoading: (NSURLConnection *) connection
{
    // do something with the data
    // receivedData is declared as a property elsewhere
    NSLog(@"Succeeded! Received %ld bytes of data", [_receivedData length]);
    
    // For now, request objects are transient, but I wonder if we need to make
    // them persistent (and pooled).
    
    _connection = nil;
    _receivedData = nil;
}
@end
