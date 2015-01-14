//
//  MMNetworkRequest.h
//  mugmover
//
//  Created by Bob Fitterman on 1/9/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MMPhoto;

@interface MMNetworkRequest : NSObject

@property (strong)              NSURLConnection *        connection;
@property (strong)              MMPhoto *                delegate;
@property (strong)              NSMutableData *          receivedData;
@property (strong)              NSMutableURLRequest *    request;
@property (assign)              NSInteger                retries;

// TODO Add retry count and automatic retries

- (id) initMakeHeadRequest: (NSString *) stringUrl
                  delegate: (MMPhoto *) delegate;

- (void) releaseStrongPointers;
- (BOOL) retryable;

@end
