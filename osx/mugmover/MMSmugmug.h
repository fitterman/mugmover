//
//  MMSmugmug.h
//  mugmover
//
//  Created by Bob Fitterman on 03/17/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MMFace.h"
@class MMOauthSmugmug;

@interface MMSmugmug : NSObject

@property (strong)              NSString *              accessSecret;
@property (strong)              NSString *              accessToken;
@property (strong)              MMPhoto *               currentPhoto;
@property (assign)              NSInteger               currentPhotoIndex;
@property (strong)              NSString *              handle; /* TODO Verify reasoning for strong */
@property (assign)              Float32                 initializationProgress;
@property (strong)              MMPhotoLibrary *        library;
@property (assign, readonly)    NSInteger               page;
@property (strong)              NSMutableDictionary *   photoDictionary;
@property (assign)              NSInteger               photosInStream;
@property (strong, readonly)    MMOauthSmugmug *        smugmugOauth;
@property (strong, readonly)    NSOperationQueue *      streamQueue;
@property (strong, readonly)    NSString *              tokenSecret;

- (void) close;

- (id) initWithHandle: (NSString *) handle
          libraryPath: (NSString *) libraryPath;

@end


