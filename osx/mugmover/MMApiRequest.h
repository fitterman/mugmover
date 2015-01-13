//
//  MMApiRequest.h
//  mugmover
//
//  Created by Bob Fitterman on 1/8/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MMApiRequest : NSObject

@property (strong) NSURLConnection *        connection;
@property (strong) NSMutableData *          receivedData;
@property (strong) NSMutableURLRequest *    request;

// TODO Add retry count and automatic retries

- (id) initUploadForApiVersion: (NSInteger) version
                      bodyData: (NSDictionary *)bodyData;
@end
