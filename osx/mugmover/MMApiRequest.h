//
//  MMApiRequest.h
//  mugmover
//
//  Created by Bob Fitterman on 1/8/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^ServiceResponseHandler)(NSDictionary *serviceResponseDictionary);


@interface MMApiRequest : NSObject

+ (NSError *) synchronousUpload: (NSDictionary *) bodyData // values should NOT be URLEncoded
              completionHandler: (ServiceResponseHandler) serviceResponseHandler;
@end
