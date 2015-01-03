//
//  MMPhoto.h
//  mugmover
//
//  Created by Bob Fitterman on 11/27/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ObjectiveFlickr/ObjectiveFlickr.h>
#import "MMPhoto.h"

@class MMFlickrPhotostream;

@interface MMPhoto : NSObject <OFFlickrAPIRequestDelegate>

@property (strong)              MMPoint *                  cropOrigin;
@property (assign)              Float64                    croppedHeight;
@property (assign)              Float64                    croppedWidth;
@property (strong)              NSDictionary *             exifDictionary;
@property (strong)              NSArray *                  faceArray;
@property (strong)              NSDictionary *             flickrDictionary;
@property (strong)              MMFlickrPhotostream *      stream;
@property (assign)              Float64                    masterHeight;
@property (strong)              NSString *                 masterUuid;
@property (assign)              Float64                    masterWidth;
@property (strong)              NSString *                 originalDate;
@property (strong)              NSString *                 originalFilename;
@property (assign)              Float64                    rotationAngle;
@property (readonly)            Float64                    straightenAngle;
@property (strong)              NSURL *                    smallUrl;
@property (assign)              NSInteger                  version;
@property (strong)              NSString *                 versionUuid;

- (MMPhoto *) initWithFlickrDictionary: (NSDictionary *)flickrDictionary
                        exifDictionary: (NSDictionary *)exifDictionary
                                stream: (MMFlickrPhotostream *)stream;

- (void) adjustForStraightenCropAndGetFaces;

- (Float64) aspectRatio;

- (void)fetchFlickrSizes;

- (BOOL) findMatchingInIphotoLibraryByVersionUuidAndVersion;

- (void) processPhoto;

- (NSString *)title;

@end
