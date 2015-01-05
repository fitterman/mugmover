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

@interface MMFlickrPhotostream : NSObject <OFFlickrAPIRequestDelegate>

@property (strong)              NSString *              accessSecret;
@property (strong)              NSString *              accessToken;
@property (strong)              MMPhoto *               currentPhoto;
@property (assign)              NSInteger               currentPhotoIndex;
@property (strong)              NSString *              handle; /* TODO Verify reasoning for strong */
@property (assign)              Float32                 initializationProgress;
@property (strong)              MMPhotoLibrary *        library;
@property (strong)              NSMutableDictionary *   photoDictionary;
@property (assign)              NSInteger               photosInBuffer;
@property (assign)              NSInteger               photosInStream;
@property (strong, readonly)    NSOperationQueue *      streamQueue;


+ (OFFlickrAPIRequest *)getRequestFromPoolSettingDelegate: (OFFlickrAPIRequestDelegateType) delegate;

+ (void)returnRequestToPool:(OFFlickrAPIRequest *)request;

- (void)addFaceNoteTo: (NSString *)flickrPhotoid
                 face: (MMFace *)face;

- (void)fetchExifUsingPhotoId: (NSString *)photoId
                       secret: (NSString *)secret;

- (id)initWithHandle: (NSString *)flickrHandle
         libraryPath: (NSString *)libraryPath;

- (void)nextPhoto;

- (void)removeFromPhotoDictionary: (MMPhoto *)photo;

- (BOOL) trackFailedAPIRequest: (OFFlickrAPIRequest *)inRequest
                         error: (NSError *)inError;

- (NSURL *)urlFromDictionary: (NSDictionary *)photoDict;

@end


enum MMImageSizes { MMImage75x75, /* @"75x75" */    MMImage150x150, /*@"150x150"*/
                    MMImage100 = 100, MMImage240 = 240, MMImage320 = 320,
                    MMImage500 = 500, MMImage640 = 640, MMImage800 = 800,
                    MMImage1024 = 1024, MMImageOriginal = 9999,
};
