//
//  MMFlickrPhotostream.h
//  mugmover
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MMFace.h"
@class MMFace;
@class MMOauthFlickr;
@class MMPhoto;
@class MMPhotoLibrary;

@interface MMFlickrPhotostream : NSObject

@property (strong)              NSString *              accessSecret;
@property (strong)              NSString *              accessToken;
@property (strong)              MMPhoto *               currentPhoto;
@property (assign)              NSInteger               currentPhotoIndex;
@property (strong)              MMOauthFlickr *         flickrOauth;
@property (strong)              NSString *              handle; /* TODO Verify reasoning for strong */
@property (assign)              Float32                 initializationProgress;
@property (strong)              MMPhotoLibrary *        library;
@property (assign, readonly)    NSInteger               page;
@property (strong)              NSMutableDictionary *   photoDictionary;
@property (assign)              NSInteger               photosInStream;
@property (strong, readonly)    NSOperationQueue *      streamQueue;

- (void) close;

- (id) initWithHandle: (NSString *) flickrHandle
          libraryPath: (NSString *) libraryPath;

- (void) getPhotos;

- (NSInteger) inQueue;

- (void) removeFromPhotoDictionary: (MMPhoto *) photo;

@end


