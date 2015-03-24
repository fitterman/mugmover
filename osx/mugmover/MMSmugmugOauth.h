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

@property (strong)              NSString *      accessToken;
@property (assign, readonly)    float           initializationStatusValue;
@property (strong, readonly)    NSString *      initializationStatusString;
@property (strong)              NSString *      tokenSecret;

- (id) initAndStartAuthorization;

- (void) close;

- (void) updateState: (float) state
              asText: (NSString *) text;
@end
