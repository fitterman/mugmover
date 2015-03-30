//
//  MMNetworkRequest.h
//  mugmover
//
//  Created by Bob Fitterman on 1/9/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MMPhoto;

typedef void (^AsyncCompletionHandler)(NSURLResponse *, NSData *, NSError *);

@interface MMNetworkRequest : NSObject

// TODO Add retry count and automatic retries

+ (void) getUrlByteLength: (NSString *) urlString
                    photo: (MMPhoto *) photo;
@end
