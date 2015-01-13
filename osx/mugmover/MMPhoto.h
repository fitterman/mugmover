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
@property (readonly)            BOOL                        didFetchOriginalByteSize;
@property (readonly)            BOOL                        didFetchExif;
@property (readonly)            BOOL                        didFetchInfo;
@property (readonly)            BOOL                        didFetchSizes;
@property (readonly)            BOOL                        didProcessPhoto;
@property (strong)              NSMutableArray *            faceArray;
@property (strong)              NSDictionary *              flickrDictionary;
@property (strong)              OFFlickrAPIRequest          *flickrRequest;
@property (assign)              Float64                     masterHeight;
@property (strong)              NSString *                  masterUuid;
@property (assign)              Float64                     masterWidth;
@property (strong)              NSMutableArray *            oldNotesToDelete;
@property (strong)              NSString *                  originalDate;
@property (strong)              NSString *                  originalFilename;
@property (strong)              NSString *                  originalUrl;
@property (strong)              MMNetworkRequest *          request;
@property (assign)              Float64                     rotationAngle;
@property (readonly)            Float64                     straightenAngle;
@property (strong)              MMFlickrPhotostream *       stream;
@property (assign)              NSInteger                   version;
@property (strong)              NSString *                  versionUuid;

- (MMPhoto *) initWithFlickrDictionary: (NSDictionary *)flickrDictionary
                                stream: (MMFlickrPhotostream *)stream;

- (void) adjustForStraightenCropAndGetFaces;

- (Float64) aspectRatio;

- (void) performNextStep;

- (void) mmNetworkRequest: (MMNetworkRequest *) request
  didCompleteWithResponse: (NSDictionary *) dictionary;

- (void) mmNetworkRequest: (MMNetworkRequest *) request
         didFailWithError: (NSError *) error;

- (void) processPhoto;

- (void) setByteLength: (long long) length;

- (NSString *)title;

@end
