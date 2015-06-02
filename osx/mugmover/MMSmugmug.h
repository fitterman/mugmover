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
@class MMPhotoLibrary;

@interface MMSmugmug : NSObject

@property (strong)              NSString *              accessSecret;
@property (strong)              NSString *              accessToken;
@property (strong)              MMPhoto *               currentPhoto;
@property (strong)              NSMutableArray *        errorLog;
@property (strong, readonly)    NSString *              handle;
@property (assign, readonly)    NSInteger               page;
@property (strong, readonly)    MMOauthSmugmug *        smugmugOauth;
@property (strong, readonly)    NSString *              tokenSecret;
@property (strong)              NSString *              uniqueId;



+ (NSString *) sanitizeUuid: (NSString *) inUrl;

- (void) authenticate: (void (^) (BOOL)) completionHandler;

- (void) close;

- (void) configureOauthRetryOnFailure: (BOOL) attemptRetry;

- (NSString *) findOrCreateAlbum: (NSString *) urlName
                        inFolder: (NSString *) folderId
                     displayName: (NSString *) displayName
                     description: (NSString *) description;

- (NSString *) findOrCreateFolderForLibrary: library;

- (BOOL) getUserInfo;

- (id) initFromDictionary: (NSDictionary *) dictionary;

- (void) logError: (NSError *) error;

- (NSString *) name;

- (NSDictionary *) serialize;


@end

