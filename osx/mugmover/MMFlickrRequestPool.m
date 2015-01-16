//
//  MMFlickrRequestPool.m
//  mugmover
//
//  Created by Bob Fitterman on 1/5/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMFlickrRequest.h"
#import "MMFlickrRequestPool.h"

@implementation MMFlickrRequestPool

#define MAX_POOL_SIZE (20)
#define MAX_RETRIES (5)


// This class wraps the OFFlickrAPIRequest class in another class that keeps track of retries
// on the request and allocation of the objects from a pool. The handle returned by the method
// to alloate and manage the objects is the id of an OFFLickrAPI Request, which is for the
// convenience of the caller, because generally a failure occurs down inside a delegate method,
// which doesn't know about this wrapper class.


- (id) initWithContext: (OFFlickrAPIContext *) flickrContext
{
    self = [self init];
    if (self)
    {
        /* Create the request pool */
        
        _availableFlickrRequestPool = [[NSMutableArray alloc] initWithCapacity: MAX_POOL_SIZE];
        _activeFlickrRequestPool = [[NSMutableDictionary alloc] init];
        _flickrContext = flickrContext;
        
        if (!_availableFlickrRequestPool || !_activeFlickrRequestPool)
        {
            return nil;
        }
    }
    return self;
}

- (BOOL) canRetry: (OFFlickrAPIRequest *) request
{
    @synchronized(_availableFlickrRequestPool)
    {
        NSString *requestKey = [NSString stringWithFormat: @"%lx", (NSInteger)(request)];
        MMFlickrRequest *wrappedRequest = [_activeFlickrRequestPool objectForKey: requestKey];
        
        if (wrappedRequest)
        {
            wrappedRequest.retriesRemaining -= 1;
            return (wrappedRequest.retriesRemaining > 0);
        }
        return NO;
    }
}

- (OFFlickrAPIRequest *) getRequestFromPoolSettingDelegate: (OFFlickrAPIRequestDelegateType) delegate
{
    @synchronized(_availableFlickrRequestPool)
    {
        NSInteger last = [_availableFlickrRequestPool count];
        MMFlickrRequest *wrappedRequest;
        if (last > 0)
        {
            last = last - 1;
            wrappedRequest = [_availableFlickrRequestPool objectAtIndex: last];
            [_availableFlickrRequestPool removeObjectAtIndex: last];
        }
        else
        {
            wrappedRequest = [[MMFlickrRequest alloc] initWithContext: _flickrContext];
            if (!wrappedRequest)
            {
                @throw [NSException exceptionWithName: @"PoolManagement"
                                               reason: @"Unable to allocate new request"
                                             userInfo: nil];
            }
        }
        [wrappedRequest.request setDelegate: delegate];
        
        // Note that we use the request id for the key, not the wrapped request
        NSString *requestKey = [NSString stringWithFormat: @"%lx", (NSInteger)(wrappedRequest.request)];
        [_activeFlickrRequestPool setObject: wrappedRequest forKey: requestKey];
        DDLogInfo(@"POOL STATS   active=%lu, available=%lu",
                  (unsigned long)[_activeFlickrRequestPool count],
                  (unsigned long)[_availableFlickrRequestPool count]);

        return wrappedRequest.request;
    }
}

- (void) returnRequestToPool: (OFFlickrAPIRequest *) request
{
    @synchronized(_availableFlickrRequestPool)
    {
        NSString *requestKey = [NSString stringWithFormat: @"%lx", (NSInteger)(request)];
        NSObject *wrappedRequest = [_activeFlickrRequestPool objectForKey: requestKey];
        
        if (!wrappedRequest)
        {
            @throw [NSException exceptionWithName: @"PoolManagement"
                                           reason: @"Unable to find request in active pool"
                                         userInfo: nil];
        }
        else
        {
            [_activeFlickrRequestPool removeObjectForKey: requestKey];
            [_availableFlickrRequestPool addObject: wrappedRequest];
        }
        DDLogInfo(@"POOL STATS   active=%lu, available=%lu",
              (unsigned long)[_activeFlickrRequestPool count],
              (unsigned long)[_availableFlickrRequestPool count]);
    }
}

- (void) releaseAll
{
    @synchronized(_availableFlickrRequestPool)
    {
        [_activeFlickrRequestPool removeAllObjects];
        _activeFlickrRequestPool = nil;
        _availableFlickrRequestPool = nil;
    }
}
@end
