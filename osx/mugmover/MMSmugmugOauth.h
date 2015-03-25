//
//  MMSmugmugOauth.h
//  mugmover
//
//  Created by Bob Fitterman on 3/24/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <TDOAuth.h>

@interface MMSmugmugOauth : TDOAuth

typedef void (^ProgresBlockType)(Float32, NSString *);

@property (strong, readonly)    NSString *          accessToken;
@property (assign, readonly)    float               initializationStatusValue;
@property (strong, readonly)    NSString *          initializationStatusString;
@property (strong, readonly)    NSString *          tokenSecret;
@property (strong, readonly)    ProgresBlockType    progressBlock;

- (id) initAndStartAuthorization: (ProgresBlockType) progressBlock;

- (id) initWithStoredToken: (NSString *) token
                    secret: (NSString *) secret;

- (NSURLRequest *)apiRequest: (NSString *) api
                  parameters: (NSDictionary *) parameters
                        verb: (NSString *) verb;

- (void) close;

@end
