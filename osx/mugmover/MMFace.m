//
//  MMFace.m
//  mugmover
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//

#import "MMFace.h"
#import "MMPhoto.h"
#import "MMPoint.h"
#include <tgmath.h>
#include "MMEnvironment.h"

@implementation MMFace

#define FLICKR_TARGET_IMAGE_MAX (500)
#define UNDEFINED_ANGLE ((Float64)(-1.0))

- (id) initFromIphotoWithTopLeft: (MMPoint *) topLeft
                      bottomLeft: (MMPoint *) bottomLeft
                     bottomRight: (MMPoint *) bottomRight
                       faceWidth: (NSInteger) faceWidth
                      faceHeight: (NSInteger) faceHeight
                          ignore: (BOOL) ignore
                        rejected: (BOOL) rejected
                        faceUuid: (NSString *) faceUuid
                           photo: (MMPhoto *) photo;
{

    self = [self init];
    if (self)
    {
        _photo = photo;
        _thumbnail = @""; // It needs to be an empty string if it doesn't exist
        {
            DDLogInfo(@"PROC'ING FACE faceUdid=%@", faceUuid);
            DDLogInfo(@"INPUTS        topLeft=%@ bottomLeft=%@ bottomRight=%@ %3.1fWx%3.1fH",
                    topLeft, bottomLeft, bottomRight, photo.masterWidth, photo.masterHeight);
        }

        // iPhoto coordinates are arranged with the origin at the bottom left. The
        // units of measurement are 0.0 to 1.0, which means that if you don't have a
        // square master image, the units are not linear with respect to one another.
        // For this reason, it is necessary to convert the units to pixels first.

        [topLeft scaleByXFactor: _photo.masterWidth yFactor: _photo.masterHeight];
        [bottomLeft scaleByXFactor: _photo.masterWidth yFactor: _photo.masterHeight];
        [bottomRight scaleByXFactor: _photo.masterWidth yFactor: _photo.masterHeight];

        {
            DDLogInfo(@"SCALED PTS    topLeft=%@ bottomLeft=%@ bottomRight=%@",
                    topLeft, bottomLeft, bottomRight);
        }

        _centerPoint = [MMPoint midpointOf: topLeft and: bottomRight];
        if (!_centerPoint)
        {
            return nil;
        }

        /* TODO On some photos, it appears the faces are smaller than the area marked in iPhoto
                which might be the case with all photos but only noticeable in certain cases.
                I am speculating that it might be necessary to consider the faceAngle column
                and apply the sin/cos of that angle to the width/height of the face.
        */
        _faceWidth = [MMPoint distanceBetween: bottomLeft and: bottomRight];
        _faceHeight = [MMPoint distanceBetween: bottomLeft and: topLeft];

        _faceUuid = faceUuid;
        _masterUuid = photo.masterUuid;
        _ignore = ignore;
        _rejected = rejected;
        _visible = YES;

        {
            DDLogInfo(@"END OF INIT   centerPoint=%@ masterDims=(%3.1fWx%3.1fH)",
                    _centerPoint, _photo.masterWidth, _photo.masterHeight);
        }
    }
    return self;
}

- (void) rotate: (Float64) degrees
         origin: (MMPoint *) centerPoint
{
    {
        DDLogInfo(@"BEFORE ROTATE centerPoint=%@ %3.1fWx%3.1fH",
                _centerPoint, _photo.masterWidth, _photo.masterHeight);
        DDLogInfo(@"ROTATION      degrees=%3.1f origin=%@",
                degrees, centerPoint);
    }
    [self.centerPoint rotate: degrees relativeTo: centerPoint];

    {
        DDLogInfo(@"AFTER ROTATE  centerPoint=%@ %3.1fWx%3.1fH",
                _centerPoint, _photo.masterWidth, _photo.masterHeight);
    }
}

- (void) setName: (NSString *) name
    faceNameUuid: (NSString *) faceNameUuid
         faceKey: (NSInteger) faceKey
  keyVersionUuid: (NSString *) keyVersionUuid
          manual: (BOOL) manual
{
    _name = name ? name : @"";
    _faceNameUuid = faceNameUuid ? faceNameUuid : @"";
    _faceKey = faceKey;
    _keyVersionUuid = keyVersionUuid ? keyVersionUuid : @"";
    _manual = manual;
}

- (NSDictionary *) properties
{
    return @{
             @"center":            [_centerPoint asIntDictionary],
             @"height":            [NSNumber numberWithLongLong: _faceHeight],
             @"ignore":            @(_ignore),
             @"rejected":          @(_rejected),
             @"uuid":              _faceUuid,
             @"visible":           @(_visible),
             @"width":             [NSNumber numberWithLongLong: _faceWidth],
             @"faceNameUuid":      _faceNameUuid,
             @"faceKey":           @(_faceKey),
             @"name":              _name,
             @"keyVersionUuid":    _keyVersionUuid,
             @"manual":            @(_manual),
             @"thumbnail":         _thumbnail,
             @"thumbscale":        @(_scaleFactor),
             };
}

- (BOOL) visibleWithCroppedWidth: (Float64) width
                   croppedHeight: (Float64) height;
{
    _visible = ((_centerPoint.x - (_faceWidth / 2.0) >= 0.0) && (_centerPoint.x - (_faceWidth / 2.0) < width) &&
                (_centerPoint.y - (_faceHeight / 2.0) >= 0.0) && (_centerPoint.y + (_faceHeight / 2.0) < height));
    {
        DDLogInfo(@"SET VISIBLITY centerPoint=%@ %3.1fWx%3.1fH visibility=%d",
                _centerPoint, width, height, _visible);
    }
    return _visible;
}

#pragma mark FlickrHelperMethods

- (Float64) flickrImageHeight
{
    Float64 ar = [_photo aspectRatio];
    if (ar < 1.0)
    {
        return (Float64) FLICKR_TARGET_IMAGE_MAX;
    }
    else
    {
        return (Float64) FLICKR_TARGET_IMAGE_MAX / ar;
    }
}

- (Float64) flickrImageWidth
{
    Float64 ar = [_photo aspectRatio];
    if (ar >= 1.0)
    {
        return (Float64) FLICKR_TARGET_IMAGE_MAX;
    }
    else
    {
        return (Float64) FLICKR_TARGET_IMAGE_MAX * ar;
    }
}

- (NSString *) flickrNoteText
{
    if ([_name isEqualToString: @""])
    {
        return [NSString stringWithFormat: @"Add the name on mugmover: %@", _faceUuid];
    }
    else
    {
        return [NSString stringWithFormat: @"Name provided by mugmover: %@ (%@)", _name, _faceUuid];
    }
}

- (void) moveCenterRelativeToTopLeftOrigin
{
    _centerPoint.y = _photo.croppedHeight - _centerPoint.y;
}

- (NSString *) flickrNoteX
{
    Float64 result = _centerPoint.x - (_faceWidth / 2.0);
    result *= ([self flickrImageWidth] / _photo.croppedWidth); /* Now scale it */
    return [NSString stringWithFormat: @"%ld", (NSInteger) round(result)];
}

/* Flickr origin is topLeft while iPhoto origin is bottomLeft */
- (NSString *) flickrNoteY
{
    Float64 result = _centerPoint.y - (_faceHeight / 2.0);
    result *= ([self flickrImageHeight] / _photo.croppedHeight); /* Now scale it */
    return [NSString stringWithFormat: @"%ld", (NSInteger) round(result)];
}

- (NSString *) flickrNoteWidth
{
    Float64 result = _faceWidth;
    result *= ([self flickrImageWidth] / _photo.croppedWidth); /* Now scale it */
    return [NSString stringWithFormat: @"%ld", (NSInteger) result];
}

- (NSString *) flickrNoteHeight
{
    Float64 result = _faceHeight;
    result *= ([self flickrImageHeight] / _photo.croppedHeight); /* Now scale it */
    return [NSString stringWithFormat: @"%ld", (NSInteger) result];
}

- (void) releaseStrongPointers
{
    _centerPoint = nil;
    _faceNameUuid = nil;
    _faceUuid = nil;
    _keyVersionUuid = nil;
    _masterUuid = nil;
    _name = nil;
    _thumbnail = nil;
}

@end