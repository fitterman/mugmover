//
//  MMDestinationSmugmug.h
//  mugmover
//
//  Created by Bob Fitterman on 03/17/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MMDestinationAbstract.h"

@class MMOauthSmugmug;
@class MMLibraryEvent;
@class MMPhotoLibrary;
@class MMUploadOperation;
@class MMWindowController;

@interface MMDestinationSmugmug : MMDestinationAbstract

@property (strong, readonly)    NSString *              handle;
@property (assign, readonly)    NSInteger               page;
@property (strong, readonly)    MMOauthSmugmug *        smugmugOauth;

+ (NSString *) sanitizeUuid: (NSString *) inUrl;

- (void) authenticate: (void (^) (BOOL)) completionHandler;

- (void) configureOauthRetryOnFailure: (BOOL) attemptRetry;

- (NSString *) createAlbumWithUrlName: (NSString *) urlName
                             inFolder: (NSString *) folderId
                          displayName: (NSString *) displayName
                          description: (NSString *) description;

- (BOOL) deleteAlbumId: (NSString *) albumId;

- (BOOL) deletePhotoId: (NSString *) photoId;

- (BOOL) getUserInfo;

- (BOOL) hasAlbumId: (NSString *) albumId;

- (NSDictionary *) imageSizesForPhotoId: (NSString *) photoId;

- (id) initFromDictionary: (NSDictionary *) dictionary;

- (NSString *) md5ForPhotoId: (NSString *) photoId;

- (NSString *) name;

- (NSString *) oauthAccessToken;

- (NSString *) oauthTokenSecret;

- (void) transferPhotosForEvent: (MMLibraryEvent *) event
                uploadOperation: (MMUploadOperation *) uploadOperation
               windowController: (MMWindowController *) windowController
                       folderId: (NSString *) folderId;
@end

