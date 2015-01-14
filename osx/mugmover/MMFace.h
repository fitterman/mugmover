//
//  MMFace.h
//  mugmover
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
@class MMPhoto;
@class MMPoint;

#define DEGREES_PER_RADIAN ((double)180.0 / 3.141592653589793238)

@interface MMFace : NSObject

// The location of a face is actually based on polar coordinates (from the master's center)
@property (readonly, strong)    MMPoint *   centerPoint;
@property (readonly)            NSInteger   faceKey;
@property (assign)              Float64     faceHeight;
@property (strong, readonly)    NSString *  faceNameUuid;
@property (strong)              NSString *  faceUuid;
@property (assign)              Float64     faceWidth;
@property (assign, readonly)    BOOL        ignore;
@property (strong, readonly)    NSString *  keyVersionUuid;
@property (strong)              NSString *  masterUuid;
@property (strong, readonly)    NSString *  name;
@property (weak)                MMPhoto *   photo;
@property (assign, readonly)    BOOL        rejected;
@property (assign, readonly)    BOOL        visible;

- (id) initFromIphotoWithTopLeft: (MMPoint *) topLeft
                      bottomLeft: (MMPoint *) bottomLeft
                     bottomRight: (MMPoint *) bottomRight
                       faceWidth: (NSInteger) faceWidth
                      faceHeight: (NSInteger) faceHeight
                          ignore: (BOOL) ignore
                        rejected: (BOOL) rejected
                        faceUuid: (NSString *) faceUuid
                           photo: (MMPhoto *) photo;

- (Float64) flickrImageHeight;
- (Float64) flickrImageWidth;

- (NSString *) flickrNoteX;
- (NSString *) flickrNoteY;
- (NSString *) flickrNoteWidth;
- (NSString *) flickrNoteHeight;
- (NSString *) flickrNoteText;

- (NSDictionary *) properties;

- (void) moveCenterRelativeToTopLeftOrigin;

- (void) rotate: (Float64) degrees
         origin: (MMPoint *) centerPoint;

- (void) releaseStrongPointers;

- (void) setName: (NSString *) name
    faceNameUuid: (NSString *) faceNameUuid
         faceKey: (NSInteger) faceKey
  keyVersionUuid: (NSString *) keyVersionUuid;

- (BOOL) visibleWithCroppedWidth: (Float64) width
                   croppedHeight: (Float64) height;

@end
