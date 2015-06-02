//
//  MMDataUtility.h
//  mugmover
//
//  Created by Bob Fitterman on 4/1/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MMDataUtility : NSObject

+ (NSError *) makeErrorForFilePath: (NSString *) filePath
                        codeString: (NSString *) codeString;

+ (NSInteger) makeSyncJsonRequestWithRetries: (NSURLRequest *) request
                                  parsedData: (NSDictionary **) parsedServerData;

+ (NSString *) parseHexToOurBase64: (NSString *) hexString;

+ (NSDictionary *) parseJsonData: (NSData *)data;

+ (NSString *) percentEncodeAlmostEverything: (NSString *) inString;

@end
