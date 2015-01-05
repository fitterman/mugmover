//
//  MMFlickrRequest.m
//  Pods
//
//  Created by Bob Fitterman on 1/5/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//
//

#import "MMFlickrRequest.h"

@implementation MMFlickrRequest

#define MAX_POOL_SIZE (20)
#define MAX_RETRIES (5)


// This class wraps the OFFlickrAPIRequest class in another class that keeps track of retries
// on the request. The handle returned by the class method and used to manage the objects is
// the id of an OFFLickrAPI Request, which is for the convenience of the caller, because generally
// a failure occurs down inside a delegate method, which doesn't know about this wrapper class.


- (id) initWithContext: (OFFlickrAPIContext *) flickrContext
{
    self = [self init];
    if (self)
    {
        _retriesRemaining = MAX_RETRIES;
        _request = [[OFFlickrAPIRequest alloc] initWithAPIContext: flickrContext];
        if (_request)
        {
            _request.sessionInfo = @"OAuth";
        }
        else
        {
            return nil;
        }
    }
    return self;
    
}

@end
