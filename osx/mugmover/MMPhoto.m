//
//  MMPhoto.m
//  mugmover
//
//  Created by Bob Fitterman on 11/27/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//

// TODO Review "SharingActivity.db" for matches

#import "FMDB/FMDatabase.h"
#import "FMDB/FMDatabaseAdditions.h"
#import "FMDB/FMResultSet.h"
#import "MMFlickrPhotostream.h"
#import "MMPhoto.h"
#import "MMPhotolibrary.h"
#import "MMPoint.h"
#import "MMFace.h"
#import "MMEnvironment.h"

@implementation MMPhoto

- (MMPhoto *) initWithFlickrDictionary: (NSDictionary *)flickrDictionary
                        exifDictionary: (NSDictionary *)exifDictionary
                                stream: (MMFlickrPhotostream *)stream
{
    self = [self init];
    if (self)
    {
        if (stream && flickrDictionary)
        {
            _stream = stream;
            _rotationAngle = 0.0;
            _straightenAngle = 0.0;
            _cropOrigin = [[MMPoint alloc] initWithX: 0.0 y: 0.0];
            if (!_cropOrigin)
            {
                return nil;
            }

            _flickrDictionary = flickrDictionary;
            _exifDictionary = exifDictionary;
            self.smallUrl = [stream urlFromDictionary:flickrDictionary];
            
            // Now that you have an MMPhoto instance, store some things you will need later
            _originalFilename = [_exifDictionary objectForKey: @"IPTC:ObjectName"];
            _originalDate = [_exifDictionary objectForKey: @"ExifIFD:DateTimeOriginal"];

            // The versionUuid might be in one of two places. Check one if the other isn't there.
            _versionUuid = [_exifDictionary objectForKey: @"IPTC:SpecialInstructions"];
            if (!_versionUuid)
            {
                _versionUuid = [_exifDictionary objectForKey: @"XMP-photoshop:Instructions"];
            }
            NSObject *versionObject = [_exifDictionary objectForKey: @"IPTC:ApplicationRecordVersion"];
            _version = (versionObject) ? [(NSString *)versionObject integerValue] : -1;

        }
        else
        {
            return nil;
        }

    }
    return self;
}

- (BOOL) findMatchingInIphotoLibraryByVersionUuidAndVersion
{
    // Try to find the matching object in the library
    if ((_version != -1) && _versionUuid)
    {
        NSNumber *number = [NSNumber numberWithInteger: _version - 1];
        NSArray *args = [NSArray arrayWithObjects: _versionUuid, number, nil];
        
        FMResultSet *resultSet = [_stream.library.photosDatabase executeQuery: @"SELECT * FROM RKVersion WHERE uuid = ? AND versionNumber = ?"
                                                         withArgumentsInArray: args];
        
        if (resultSet && [resultSet next])
        {
            [self updateFromIphotoLibraryVersionRecord: resultSet];
            return YES;
        }
    }
    return NO;
}

// Using the width, height and date (already acquired), look for a match
- (BOOL) findMatchingVersionInIphotoLibrary: (MMPhotoLibrary *) library
                                 usingWidth: (NSString *) width
                                     height: (NSString *) height
{
    
    // This process is problematic. Using the image dimensions and its original name,
    // we can find any number of matches. To narrow those down to the right image, it
    // is necessary to find images that have matching EXIF data. In fact, we may find
    // multiple matches and will have to take a guess which is the best match.

    NSString *query = @"SELECT v.versionNumber version, v.uuid versionUuid, m.uuid, imagePath, v.filename filename, "
                             "masterUuid, masterHeight, masterWidth, rotation, isOriginal "
                       "FROM RKVersion v JOIN RKMaster m ON m.uuid = v.masterUuid "
                       "WHERE m.isInTrash != 1 AND m.originalVersionName  = ? AND "
                             "v.processedWidth = ? AND v.processedHeight = ? "
                       "ORDER BY v.versionNumber DESC ";
            ;
    NSArray *args = [NSArray arrayWithObjects: _originalFilename, width, height, nil];
    FMResultSet *resultSet = [library.photosDatabase executeQuery: query
                                             withArgumentsInArray: args];

    NSString *flickrModifyTime = [_exifDictionary valueForKey: @"IFD0:ModifyDate"];
    NSString *flickrOriginalTime = [_exifDictionary valueForKey: @"ExifIFD:DateTimeOriginal"];

    if (resultSet)
    {
        while ([resultSet next])
        {
            NSDictionary *exif = nil;

            NSString *masterPath = [resultSet stringForColumn: @"imagePath"];
            NSString *versionFilename = [resultSet stringForColumn: @"filename"];
            NSString *versionUuid = [resultSet stringForColumn: @"versionUuid"];

            if ([resultSet boolForColumn: @"isOriginal"])
            {
                exif = [MMPhotoLibrary versionExifFromMasterPath: masterPath];
            }
            else
            {
                
                exif = [MMPhotoLibrary versionExifFromMasterPath: masterPath
                                                     versionUuid: versionUuid
                                                 versionFilename: versionFilename];
            }
            
            if (exif)
            {
                NSString *iphotoModifyTime = [[exif objectForKey: @"{TIFF}"] valueForKey: @"DateTime"];
                NSString *iphotoOriginalTime = [[exif objectForKey: @"{Exif}"] valueForKey: @"DateTimeOriginal"];
                
                if ((iphotoModifyTime && [iphotoModifyTime isEqualToString: flickrModifyTime]) &&
                    (iphotoOriginalTime && [iphotoOriginalTime isEqualToString: flickrOriginalTime]))
                    
                {
                    _versionUuid = versionUuid;
                    _version = [[resultSet stringForColumn: @"version"] intValue];
                    [self updateFromIphotoLibraryVersionRecord: resultSet];
                    NSLog(@"MATCH ACCEPTED");
                    return YES;
                }
                NSLog(@"MATCH REJECTED  iphotoModifyTime=%@, flickrModifyTime=%@, iphotoOriginalTime=%@, flickrOriginalTime=%@",
                            iphotoModifyTime, flickrModifyTime, iphotoOriginalTime, flickrOriginalTime);
            }
            else
            {
                NSLog(@"VERSION NOT FOUND");
                continue;
            }
// TODO >>>            [self updateFromMatchingIphotoVersionRecord: resultSet];
        }
    }
    return NO;
}

- (void) adjustForStraightenCropAndGetFaces
{
    MMPoint *straightenCenterPoint = [[MMPoint alloc] initWithX: _masterWidth / 2.0 y: _masterHeight / 2.0];
    if (straightenCenterPoint)
    {
        _faceArray = [self straighten: _straightenAngle
                               around: straightenCenterPoint
                               cropAt: _cropOrigin
                                width: _croppedWidth
                               height: _croppedHeight
                               rotate: _rotationAngle];
        _masterWidth = _croppedWidth;
        _masterHeight = _croppedHeight;
        
    }
    else
    {
        NSLog(@"Failed to create center point(s) for crop or rotation");
    }
}

- (void) updateFromIphotoLibraryVersionRecord: (FMResultSet *)resultSet
{
    if (resultSet)
    {
        _masterUuid   = [resultSet stringForColumn: @"masterUuid"];
        _masterHeight = (Float64)[resultSet intForColumn: @"masterHeight"];
        _masterWidth  = (Float64)[resultSet intForColumn: @"masterWidth"];
        _rotationAngle = (Float64)[resultSet intForColumn: @"rotation"];
    }
}

- (NSArray *) findRelevantAdjustments
{
    /* Be sure these are initialized each time */

    _croppedWidth = _masterWidth;
    _croppedHeight = _masterHeight;
    if (!self.versionUuid)
    {
        return nil;
    }

    FMDatabase *photosDb = [self.stream.library photosDatabase];
    if (photosDb)
    {
        NSArray *args = [NSArray arrayWithObjects: self.versionUuid, nil];
        NSString *adjQuerySql = @"SELECT * FROM RKImageAdjustment "
                                 "WHERE name IN ('RKCropOperation', 'RKStraightenCropOperation') "
                                 "AND isEnabled = 1 "
                                 "AND versionUuid = ? "
                                 "ORDER BY adjIndex";

        FMResultSet * adjustments = [photosDb executeQuery: adjQuerySql
                                      withArgumentsInArray: args];
        if (!adjustments)
        {
            // NSLog(@"    FMDB error=%@", [photosDb lastErrorMessage]);
            return nil;
        }

        while ([adjustments next])
        {
            NSString *operationName = [adjustments stringForColumn: @"name"];
            // NSLog(@"    operationName=%@", operationName);

            NSData *blob = [adjustments dataForColumn: @"data"];
            if (blob)
            {
                // The blob contains a "root" element which is a serialized dictionary
                // Within the dictionary is the "inputKeys" key and its value is another dictionary
                NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData: blob];
                if ([unarchiver containsValueForKey: @"root"])
                {
                    NSDictionary *parameters = (NSDictionary *)[unarchiver decodeObjectForKey: @"root"];
                    if (parameters)
                    {
                        NSNumber *operationVersion = [parameters valueForKeyPath: @"DGOperationVersionNumber"];
                        if ([operationVersion intValue] != 0)
                        {
                            @throw [NSException exceptionWithName: @"UnexpectedOperationParameter"
                                                           reason: @"Unexpected Version Number ("
                                                         userInfo: parameters];
                        }
                        if ([operationName isEqualToString: @"RKCropOperation"])
                        {
                            _croppedWidth = [[parameters valueForKeyPath: @"inputKeys.inputWidth"] intValue];
                            _croppedHeight = [[parameters valueForKeyPath: @"inputKeys.inputHeight"] intValue];
                            Float64 x = (Float64) [[parameters valueForKeyPath: @"inputKeys.inputXOrigin"] intValue];
                            Float64 y = (Float64) [[parameters valueForKeyPath: @"inputKeys.inputYOrigin"] intValue];
                            _cropOrigin.x += x;
                            _cropOrigin.y += y;
                            if (MMdebugging)
                            {
                                NSLog(@"SET CROP TO   cropOrigin=%@ %3.1fWx%3.1fH", _cropOrigin, _croppedWidth, _croppedHeight);
                            }
                        }
                        else if ([operationName isEqualToString: @"RKStraightenCropOperation"])
                        {
                            NSString *angle = [parameters valueForKeyPath: @"inputKeys.inputRotation"];
                            _straightenAngle += [angle floatValue];
                            if (MMdebugging)
                            {
                                NSLog(@"SET ROTATION  straigtenAngle=%3.1f", _straightenAngle);
                            }
                        }
                    }
                }
            }
        }
        return  nil;
    }
    return nil;
}

- (NSMutableArray *) straighten: (Float64) straightenAngle
                         around: (MMPoint *) straightenCenterPoint
                         cropAt: (MMPoint *) cropOrigin
                          width: (Float64) cropWidth
                         height: (Float64) cropHeight
                         rotate: (Float64) rotationAngle
{
    MMPoint *rotateCenterPoint = nil;
    NSMutableArray *result = nil;
    
    rotateCenterPoint = [[MMPoint alloc] initWithX: (cropWidth / 2.0) y: (cropHeight / 2.0)];
    if (!rotateCenterPoint)
    {
        NSLog(@"ERROR     Unable to allocate rotateCenterPoint");
        return nil;
    }
    BOOL quarterTurn = (rotationAngle == 90.0) || (rotationAngle == 270.0);

    if (!_masterUuid)
    {
        NSLog(@"WARNING   Photo has no masterUuid");
        return nil;
    }

    FMDatabase *faceDb = [self.stream.library facesDatabase];
    if (!faceDb)
    {
        NSLog(@"ERROR   No face database!");
        return nil;
    }

    NSArray *args = [NSArray arrayWithObjects: _masterUuid, nil];
    NSUInteger matches = [[[self.stream library] facesDatabase]
                                intForQuery:@"SELECT COUNT(*) cnt FROM RKDetectedFace WHERE masterUuid = ? AND ignore = 0",
                                _masterUuid];

    if (matches > 0)
    {
        result = [[NSMutableArray alloc] initWithCapacity: matches];
        if (!result)
        {
            NSLog(@"ERROR   No result returned by FMDatabase");
            return nil;
        }
        // TODO By counting rejected faces you can spot pictures with large crowds where only one person matters
        FMResultSet *resultSet = [faceDb executeQuery: @"SELECT f.*,     fn.name FROM RKDetectedFace f "
                                  "LEFT JOIN RKFaceName fn ON f.faceKey = fn.faceKey "
                                  "WHERE masterUuid = ? AND ignore = 0 AND rejected = 0"
                                 withArgumentsInArray: args];
        if (resultSet)
        {
            // When we straighten the image, the canvas size grows just enough to allow the image to
            // still fit inside the new canvas when rotated. This formula gives you the new dimensions.
            
            Float64 absStraightenAngleInRadians = fabs(straightenAngle) / DEGREES_PER_RADIAN;
            Float64 newWidth =  (_masterWidth * cos(absStraightenAngleInRadians)) +
                                (_masterHeight * sin(absStraightenAngleInRadians));
            Float64 newHeight = (_masterHeight * cos(absStraightenAngleInRadians)) +
                                (_masterWidth * sin(absStraightenAngleInRadians));
            if (MMdebugging)
            {
                NSLog(@"GROW CANVAS   %3.1fWx%3.1fH", newWidth, newHeight);
            }
            
            while ([resultSet next])
            {
                NSString *caption = [NSString stringWithFormat: @"%@ (%@)",
                                     [resultSet stringForColumn:@"uuid" ],
                                     [resultSet stringForColumn:@"name" ] ];
                
                
                MMPoint *topLeft     = [[MMPoint alloc] initWithX: [resultSet doubleForColumn:@"topLeftX" ]
                                                                y: [resultSet doubleForColumn:@"topLeftY" ]];
                MMPoint *bottomLeft  = [[MMPoint alloc] initWithX: [resultSet doubleForColumn:@"bottomLeftX" ]
                                                                y: [resultSet doubleForColumn:@"bottomLeftY" ]];
                MMPoint *bottomRight = [[MMPoint alloc] initWithX: [resultSet doubleForColumn:@"bottomRightX" ]
                                                                y: [resultSet doubleForColumn:@"bottomRightY" ]];
                NSInteger faceWidth = [resultSet intForColumn: @"width"];
                NSInteger faceHeight = [resultSet intForColumn: @"height"];


                MMFace *face = [[MMFace alloc] initFromIphotoWithTopLeft: topLeft
                                                              bottomLeft: bottomLeft
                                                             bottomRight: bottomRight
                                                               faceWidth: faceWidth
                                                              faceHeight: faceHeight

                                                                faceUuid: caption
                                                                   photo: self];
                if (face)
                {
                    if (MMdebugging)
                    {
                        NSLog(@"FACE DIMS     %3.1fWx%3.1fH", face.faceWidth, face.faceHeight);
                    }
                    [face rotate: straightenAngle origin: straightenCenterPoint];
                    
                    // Based on dimensions of the straightened image, adjust the faces and rotation
                    // point/ within the new coordinate space of the cropped image. This adjustment
                    // has to do with the size of the canvas increasing.

                    face.centerPoint.x += (newWidth - _masterWidth) / 2.0;
                    face.centerPoint.y += (newHeight - _masterHeight) / 2.0;
                    
                    // Now crop the image

                    face.centerPoint.x -= cropOrigin.x;
                    face.centerPoint.y -= cropOrigin.y;
                    
                    // Then figure out whether the face is still visible.

                    if (MMdebugging)
                    {
                        NSLog(@"ADJUSTED      centerPoint=%@", face.centerPoint);
                    }

                    BOOL visible = [face visibleWithCroppeWidth: cropWidth
                                                  croppedHeight: cropHeight];
                    if (MMdebugging)
                    {
                        NSLog(@"SET VIS       visible=%d", visible);
                    }

                    [face rotate: -rotationAngle origin: rotateCenterPoint];

                    // You need to adjust the face into a new coordinate space when there's
                    // a quarter-turn. Also flip height/width.

                    if (quarterTurn)
                    {
                        face.centerPoint.x -= (cropWidth - cropHeight) / 2.0;
                        face.centerPoint.y -= (cropWidth - cropHeight) / 2.0;
                        Float64 tmp = face.faceWidth;
                        face.faceWidth = face.faceHeight;
                        face.faceHeight = tmp;
                    }

                    [result addObject: face];
                }
            }
        }
    }

    if (quarterTurn)
    {
        _masterHeight = cropWidth;
        _masterWidth = cropHeight;
    }
    else
    {
        _masterHeight = cropHeight;
        _masterWidth = cropWidth;
    }
    if (MMdebugging)
    {
        NSLog(@"FINAL SIZE    cropOrigin=%@ cropDims=%3.1fWx%3.1fH", cropOrigin, _masterWidth, _masterHeight);
    }
    return result;

}

- (Float64) aspectRatio
{
    return _masterWidth / _masterHeight;
}

- (void) processPhoto
{
    [self findRelevantAdjustments];
    [self adjustForStraightenCropAndGetFaces];
    [self queueFacesToStream];
}

- (void)releaseStrongPointers
{
    _exifDictionary = nil;
    _faceArray = nil;
    _flickrDictionary = nil;
    _masterUuid = nil;
    _originalDate = nil;
    _originalFilename = nil;
    _smallUrl = nil;
    _stream = nil;
    _versionUuid = nil;

}
- (BOOL) queueFacesToStream
{
    BOOL result = NO;
    if (self.faceArray)
    {
        for (NSInteger i = 0 ; i < [self.faceArray count] ; i++)
        {
            MMFace *face = [self.faceArray objectAtIndex:i];
            NSBlockOperation *addFaceOperation = [NSBlockOperation blockOperationWithBlock:^
                                                  {
                                                      // // NSLog (@"  BLOCK adding face uuid=%@", face.faceUuid);
                                                      [self.stream addFaceNoteTo: [_flickrDictionary valueForKey: @"id"]
                                                                       face: face];
                                                      [face releaseStrongPointers];
                                                  }];
            [self.stream.streamQueue addOperation: addFaceOperation];
        }

        // We either have to do the releaase here (because we have faces)...
        result  = YES;
    }

// TODO     [self releaseStrongPointers];
// TODO     [_stream removeFromPhotoDictionary: self];
    return result;
}

- (NSString *)title
{
    NSString *title = [self.flickrDictionary  objectForKey:@"title"];
    if (![title length])
    {
        title = @"No title";
    }
    return title;
}

- (void)fetchFlickrSizes
{
    OFFlickrAPIRequest *flickrRequest = [MMFlickrPhotostream getRequestFromPoolSettingDelegate: self];
    if ([flickrRequest isRunning])
    {
        @throw [NSException exceptionWithName: @"PoolManagement"
                                       reason: @"Pool request is still running"
                                     userInfo: nil];
        
    }

    NSString *photoId = [_flickrDictionary valueForKey: @"id"];
    NSString *secret = [_flickrDictionary valueForKey: @"secret"];
    NSArray  *pieces = [NSArray arrayWithObjects: @"fetchSizes", photoId, secret, nil];
    flickrRequest.sessionInfo = [pieces componentsJoinedByString: @";"];

    [flickrRequest callAPIMethodWithGET: @"flickr.photos.getSizes"
                              arguments: [NSDictionary dictionaryWithObjectsAndKeys: photoId, @"photo_id",
                                          secret, @"secret",
                                          nil]];
    
}


#pragma mark ObjectiveFlickr delegate methods

- (void)flickrAPIRequest: (OFFlickrAPIRequest *)inRequest
 didCompleteWithResponse: (NSDictionary *)inResponseDictionary
{
    //    // NSLog(@"  COMPLETION: request=%@", inRequest.sessionInfo);
    if ([inRequest.sessionInfo hasPrefix: @"fetchSizes;"])
    {
        NSArray *sizeArray = [inResponseDictionary valueForKeyPath: @"sizes.size"];
        if (sizeArray)
        {
            for (NSDictionary *dict in sizeArray)
            {
                NSString *labelText = [dict objectForKey: @"label"];
                if ([labelText isEqualToString: @"Original"])
                {
                    NSString *widthString = [dict valueForKey: @"width"];
                    NSString *heightString = [dict objectForKey: @"height"];
                    if (widthString && heightString)
                    {
                        if ([self findMatchingVersionInIphotoLibrary: _stream.library
                                                          usingWidth: widthString
                                                              height: heightString])
                        {
                            NSLog(@"FOUND MATCH 2  versionUuid=%@ version=%ld", _versionUuid, _version);
                            [self processPhoto];
                        }
                        else
                        {
                            NSLog(@"UNMATCHED PHOTO   flickrId=%@ %@Wx%@H", [_flickrDictionary objectForKey: @"id"]
                                  ,
                                  widthString, heightString);
                        }
                    }
                }
            }
        }
    }

}

- (void)flickrAPIRequest: (OFFlickrAPIRequest *)inRequest
        didFailWithError: (NSError *)inError
{
    BOOL retryable = [_stream trackFailedAPIRequest: inRequest
                                              error: inError];

    if (retryable)
    {
        if ([inRequest.sessionInfo hasPrefix: @"fetchSizes;"])
        {
            [self fetchFlickrSizes]; /* Retry */
        }
    }
}

@end