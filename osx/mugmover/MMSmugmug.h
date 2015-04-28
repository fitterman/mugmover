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
@class MMLibraryEvent;
@class MMMasterViewController;
@class MMPhotoLibrary;

@interface MMSmugmug : NSObject

@property (strong)              NSString *              accessSecret;
@property (strong)              NSString *              accessToken;
@property (strong)              MMPhoto *               currentPhoto;
@property (strong, readonly)    NSString *              defaultFolder;
@property (strong)              NSString *              handle;
@property (assign)              Float32                 initializationProgress;
@property (assign, readonly)    NSInteger               page;
@property (strong, readonly)    MMOauthSmugmug *        smugmugOauth;
@property (strong, readonly)    NSString *              tokenSecret;
@property (strong)              NSString *              uniqueId;


+ (MMSmugmug *) fromDictionary: (NSDictionary *) dictionary;

+ (NSString *) sanitizeUuid: (NSString *) inUrl;

- (void) authenticate: (void (^) (BOOL)) completionHandler;

- (void) close;

- (void) configureOauthRetryOnFailure: (BOOL) attemptRetry;

- (NSString *) findOrCreateAlbum: (NSString *) urlName
                         beneath: (NSString *) partialPath
                     displayName: (NSString *) displayName
                     description: (NSString *) description;

- (NSString *) findOrCreateFolder: (NSString *) urlName
                          beneath: (NSString *) partialPath
                      displayName: (NSString *) displayName
                      description: (NSString *) description;

- (BOOL) getUserInfo;

- (NSString *) name;

- (NSDictionary *) serialize;


@end

