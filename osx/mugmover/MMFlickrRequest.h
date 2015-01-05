//
//  MMFlickrRequest.h
//  Pods
//
//  Created by Bob Fitterman on 1/5/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//
//

#import <Foundation/Foundation.h>
#import <ObjectiveFlickr/ObjectiveFlickr.h>

@interface MMFlickrRequest : NSObject

@property (strong)              OFFlickrAPIRequest *       request;
@property (assign)              NSInteger                  retriesRemaining;

- initWithContext: (OFFlickrAPIContext *) flickrContext;

@end
