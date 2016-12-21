//
//  MMPhoto.h
//  mugmover
//
//  Created by Bob Fitterman on 11/27/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MMPhoto.h"
#import "MMPhotoLibrary.h"

@class MMApiRequest;
@class MMPoint;
@class MMNetworkRequest;

@interface MMPhoto : NSObject

@property (strong, readonly)    NSMutableArray *            adjustmentsArray;
@property (strong)              MMApiRequest *              apiRequest;
@property (strong, readonly)    NSMutableDictionary *       attributes;
@property (strong)              NSString *                  caption;
@property (strong)              MMPoint *                   cropOrigin;
@property (assign, readonly)    Float64                     croppedHeight;
@property (assign, readonly)    Float64                     croppedWidth;
@property (strong)              NSMutableDictionary *       exifDictionary;
@property (strong)              NSMutableArray *            faceArray;
@property (assign)              NSInteger                   index;
@property (strong)              NSString *                  iPhotoOriginalImagePath;
@property (strong)              NSString *                  keywordList;
@property (weak, readonly)      MMPhotoLibrary *            library;
@property (assign, readonly)    Float64                     masterHeight;
@property (strong)              NSString *                  masterUuid;
@property (assign, readonly)    Float64                     masterWidth;
@property (strong)              NSMutableArray *            oldNotesToDelete;
@property (strong)              NSString *                  originalDate;
@property (strong)              NSString *                  originalFileName;
@property (strong)              NSString *                  originalUrl;
@property (assign, readonly)    Float64                     processedHeight;
@property (assign, readonly)    Float64                     processedWidth;
@property (strong)              MMNetworkRequest *          request;
@property (assign, readonly)    Float64                     rotationAngle;
@property (assign, readonly)    Float64                     straightenAngle;
@property (strong)              NSString *                  thumbnail;
@property (assign)              BOOL                        verboseLogging;
@property (assign)              NSInteger                   version;
@property (strong)              NSString *                  versionUuid;

+ (NSArray *) getPhotosForEvent: (MMLibraryEvent *) eventUuid;

+ (MMPhoto *) getPhotoByVersionUuid: (NSString *) versionUuid
                        fromLibrary: (MMPhotoLibrary *) library;

- (id) initFromDictionary: (NSDictionary *) inDictionary
                  library: (MMPhotoLibrary *) library;

- (void) adjustForStraightenCropAndGetFaces;

- (void) attachServiceDictionary: (NSDictionary *) serviceDictionary;

- (Float64) aspectRatio;

- (void) close;

- (NSString *) fileName;

- (NSNumber *) fileSize;

- (NSImage *) getThumbnailImage;

- (NSString *) fullImagePath;

- (BOOL) isFormatRequiringConversion;

- (BOOL) isGifOrPng;

- (BOOL) isTiff;

- (BOOL) isVideo;

- (NSError *) processPhoto;

- (NSError *) sendPhotoToMugmover;

- (void) setByteLength: (long long) length;

- (NSString *) title;

- (NSString *) titleForUpload;

- (void) setUrlsForLargeImage: (NSString *) urlToLargeImage
                originalImage: (NSString *) urlToOriginalImage;

- (NSString *) versionName;

@end
