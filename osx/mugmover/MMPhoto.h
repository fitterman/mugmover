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

@class MMApiRequest;
@class MMFlickrPhotostream;
@class MMPoint;
@class MMNetworkRequest;

@interface MMPhoto : NSObject <OFFlickrAPIRequestDelegate>

@property (strong)              MMApiRequest *              apiRequest;
@property (strong)              MMPoint *                   cropOrigin;
@property (assign)              Float64                     croppedHeight;
@property (assign)              Float64                     croppedWidth;
@property (strong)              NSMutableDictionary *       exifDictionary;
@property (assign, readonly)    BOOL                        didFetchOriginalByteSize;
@property (assign, readonly)    BOOL                        didFetchExif;
@property (assign, readonly)    BOOL                        didFetchInfo;
@property (assign, readonly)    BOOL                        didFetchSizes;
@property (strong)              NSMutableArray *            faceArray;
@property (strong)              NSMutableDictionary *       flickrDictionary;
@property (strong)              OFFlickrAPIRequest *        flickrRequest;
@property (assign)              NSInteger                   index;
@property (assign)              Float64                     masterHeight;
@property (strong)              NSString *                  masterUuid;
@property (assign)              Float64                     masterWidth;
@property (strong)              NSMutableArray *            oldNotesToDelete;
@property (strong)              NSString *                  originalDate;
@property (strong)              NSString *                  originalFilename;
@property (strong)              NSString *                  originalUrl;
@property (strong)              MMNetworkRequest *          request;
@property (assign)              Float64                     rotationAngle;
@property (assign, readonly)    Float64                     straightenAngle;
@property (weak)                MMFlickrPhotostream *       stream;
@property (assign)              NSInteger                   version;
@property (strong)              NSString *                  versionUuid;

- (MMPhoto *) initWithFlickrDictionary: (NSDictionary *) flickrDictionary
                                stream: (MMFlickrPhotostream *) stream
                                 index: (NSInteger) index;

- (void) adjustForStraightenCropAndGetFaces;

- (Float64) aspectRatio;

- (void) performNextStep;

- (void) mmNetworkRequest: (MMNetworkRequest *) request
  didCompleteWithResponse: (NSDictionary *) dictionary;

- (void) mmNetworkRequest: (MMNetworkRequest *) request
         didFailWithError: (NSError *) error;

- (void) processPhoto;

- (void) setByteLength: (long long) length;

- (NSString *) title;

@end
