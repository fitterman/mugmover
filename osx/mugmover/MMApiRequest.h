//
//  MMApiRequest.h
//  mugmover
//
//  Created by Bob Fitterman on 1/8/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MMApiRequest : NSObject

// TODO Add retry count and automatic retries

- (id) initUploadForApiVersion: (NSInteger) version
                      bodyData: (NSDictionary *) bodyData // values should NOT be URLEncoded
             completionHandler: (void (^)(NSURLResponse *response,
                                          NSData *data,
                                          NSError *connectionError)) handler;

@end
