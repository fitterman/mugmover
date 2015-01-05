//
//  MMFlickrRequestPool.h
//  mugmover
//
//  Created by Bob Fitterman on 1/5/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ObjectiveFlickr/ObjectiveFlickr.h>

@interface MMFlickrRequestPool : NSObject

@property (strong)              NSMutableDictionary *   activeFlickrRequestPool;
@property (strong)              NSMutableArray *        availableFlickrRequestPool;
@property (strong)              OFFlickrAPIContext *    flickrContext;

- (id) initWithContext: (OFFlickrAPIContext *) flickrContext;

- (BOOL) canRetry: (OFFlickrAPIRequest *) request;

- (OFFlickrAPIRequest *)getRequestFromPoolSettingDelegate: (OFFlickrAPIRequestDelegateType) delegate;

- (void)returnRequestToPool:(OFFlickrAPIRequest *)request;


@end
