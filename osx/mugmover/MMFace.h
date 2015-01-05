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
@property (assign)              Float64     faceWidth;
@property (assign)              Float64     faceHeight;
@property (strong)              NSString *  faceUuid;
@property (strong)              NSString *  masterUuid;
@property (strong)              MMPhoto *   photo;
@property (assign)              BOOL        visible;



- (id) initFromIphotoWithTopLeft: (MMPoint *) topLeft
                      bottomLeft: (MMPoint *) bottomLeft
                     bottomRight: (MMPoint *) bottomRight
                       faceWidth: (NSInteger) faceWidth
                      faceHeight: (NSInteger) faceHeight
                        faceUuid: (NSString *) faceUuid
                           photo: (MMPhoto *) photo;

- (Float64) flickrImageHeight;
- (Float64) flickrImageWidth;

- (NSString *) flickrNoteX;
- (NSString *) flickrNoteY;
- (NSString *) flickrNoteWidth;
- (NSString *) flickrNoteHeight;
- (NSString *) flickrNoteText;

- (void) rotate: (Float64) degrees
         origin: (MMPoint *) centerPoint;

- (void) releaseStrongPointers;

- (BOOL) visibleWithCroppeWidth: (Float64) width
                  croppedHeight: (Float64) height;

@end
