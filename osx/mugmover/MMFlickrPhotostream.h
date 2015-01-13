//
//  MMFlickrPhotostream.h
//  mugmover
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ObjectiveFlickr/ObjectiveFlickr.h>
#import "MMFace.h"
@class MMFace;
@class MMPhoto;
@class MMPhotoLibrary;
@class MMFlickrRequestPool;

@interface MMFlickrPhotostream : NSObject <OFFlickrAPIRequestDelegate>

@property (strong)              NSString *              accessSecret;
@property (strong)              NSString *              accessToken;
@property (strong)              MMPhoto *               currentPhoto;
@property (assign)              NSInteger               currentPhotoIndex;
@property (strong)              OFFlickrAPIContext *    flickrContext;
@property (strong)              NSString *              handle; /* TODO Verify reasoning for strong */
@property (assign)              Float32                 initializationProgress;
@property (strong)              MMPhotoLibrary *        library;
@property (strong)              NSMutableDictionary *   photoDictionary;
@property (assign)              NSInteger               photosInStream;
@property (strong)              MMFlickrRequestPool *   requestPool;
@property (strong, readonly)    NSOperationQueue *      streamQueue;

- (void) close;

- (id) initWithHandle: (NSString *)flickrHandle
          libraryPath: (NSString *)libraryPath;

- (void) getPhotos;

- (void)removeFromPhotoDictionary: (MMPhoto *)photo;

- (BOOL) trackFailedAPIRequest: (OFFlickrAPIRequest *)inRequest
                         error: (NSError *)inError;

- (NSURL *)urlFromDictionary: (NSDictionary *)photoDict;

@end


