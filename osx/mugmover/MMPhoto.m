//
//  MMPhoto.m
//  This class handles the overall processing of photos. Photos can be
//  initialized from a Flickr dictionary, which passes over a collection
//  of data values that are contained in the photostream request itself
//  (see MMFlickrPhotostream for details). Once the photo is init'd, the
//  "performNextStep" method is called repeatedly as each step completes,
//  and it embodies the knowledge of what happens next -- specifically
//  with regard to steps requiring network access. Finally, "processPhoto"
//  is invoked, which performs all the local processing against the
//  iPhoto library.
//
//  Created by Bob Fitterman on 11/27/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//

// TODO Review "SharingActivity.db" for matches

#import "FMDB/FMDatabase.h"
#import "FMDB/FMDatabaseAdditions.h"
#import "FMDB/FMResultSet.h"
#import "MMApiRequest.h"
#import "MMFlickrPhotostream.h"
#import "MMFlickrRequest.h"
#import "MMFlickrRequestPool.h"
#import "MMNetworkRequest.h"
#import "MMPhoto.h"
#import "MMPhotolibrary.h"
#import "MMPoint.h"
#import "MMFace.h"
#import "MMEnvironment.h"
#import "MMNetworkRequest.h"

@implementation MMPhoto

- (MMPhoto *) initWithFlickrDictionary: (NSDictionary *) flickrDictionary
                                stream: (MMFlickrPhotostream *) stream
                                 index: (NSInteger) index
{
    self = [self init];
    if (self)
    {
        _index = index;
        _flickrDictionary = [[NSMutableDictionary alloc] init];
        if (_flickrDictionary && stream && flickrDictionary)
        {
            _stream = stream;
            _rotationAngle = 0.0;
            _straightenAngle = 0.0;
            _cropOrigin = [[MMPoint alloc] initWithX: 0.0 y: 0.0];
            if (!_cropOrigin)
            {
                [self releaseStrongPointers];
                return nil;
            }
            
            for (NSString *key in flickrDictionary)
            {
                NSString *value = [flickrDictionary valueForKey: key];
                if ([key hasPrefix: @"is"])
                {
                    NSNumber *boolValue = [[NSNumber alloc ] initWithBool: ([value isEqualToString: @"1"])];
                    [_flickrDictionary setValue: boolValue forKey: key];
                }
                else
                {
                    [_flickrDictionary setValue: value forKey: key];
                }
            }
            [_flickrDictionary setValue: @"flickr" forKey: @"name"];
            _exifDictionary = [NSMutableDictionary new];
            if (!_exifDictionary)
            {
                [self releaseStrongPointers];
                return nil;
            }
            _oldNotesToDelete = [[NSMutableArray alloc] init];
            if (!_oldNotesToDelete)
            {
                [self releaseStrongPointers];
                return nil;
            }
            _adjustmentsArray = [[NSMutableArray alloc] init];
            if (!_adjustmentsArray)
            {
                [self releaseStrongPointers];
                return nil;
            }
            _flickrRequest = [_stream.requestPool getRequestFromPoolSettingDelegate: self];

            _didFetchExif = NO;
            _didFetchInfo = NO;
            _didFetchOriginalByteSize = NO;
            _didFetchSizes = NO;
        }
        else
        {
            return nil;
        }

    }
    return self;
}

- (void) performNextStep
{
    // This sequentially performs each step, ensuring that it won't go to the next step
    // from inside the network delegates by using block operations as needed.
    NSBlockOperation *blockOperation;
    if (!_didFetchExif)                     // STEP 1: Get the Exif data from Flickr
    {
        [self fetchFlickrExif];
    }
    else if (!_didFetchInfo)                // STEP 2: Perform the getInfo call to get the notes
    {
        blockOperation = [NSBlockOperation blockOperationWithBlock:^
                          {
                              [self fetchFlickrInfo];
                          }];
        [_stream.streamQueue addOperation: blockOperation];
    }
    else if (!_didFetchSizes)               // STEP 3: Get the images sizes in hopes of accessing the original image
    {
        blockOperation = [NSBlockOperation blockOperationWithBlock:^
                          {
                              [self fetchFlickrSizes];
                          }];
        [_stream.streamQueue addOperation: blockOperation];
    }
    else if (!_didFetchOriginalByteSize)    // STEP 4: Retrieve the size of the original image
    {
        blockOperation = [NSBlockOperation blockOperationWithBlock:^
                          {
                              [self fetchImageByteSize];
                          }];
        [_stream.streamQueue addOperation: blockOperation];
    }
    else
    {
        if ([self findMatchingInIphotoLibraryByVersionUuidAndVersion] ||
            [self findMatchingVersionInIphotoLibraryByAttributes])
        {
            [self processPhoto]; // This does everything
        }
        else
        {
            [self releaseStrongPointers];
            DDLogError(@"ORPHAN PHOTO  index=%ld, remaining=%ld", (long)_index, [_stream inQueue]);

            // TODO May want to start deleting any mugmover comments as a cleanup step.
            // If so, call [self updateNotesOnFlickr]] but not sure about that.
            // If you call it, remember that it still adds and deletes notes, with NO optimization.
        }
    }
}

- (void) updateNotesOnFlickr
{
    NSBlockOperation *blockOperation;
    if ((!_faceArray) || ([_faceArray count] == 0))
    {
        if ([_oldNotesToDelete count] == 0)
        {
            // We can't do this one from the delegate callback, so we queue it as well
            blockOperation = [NSBlockOperation blockOperationWithBlock:^
                              {
                                [self releaseStrongPointers];
                              }];
        }
        else
        {
            blockOperation = [NSBlockOperation blockOperationWithBlock:^
                              {
                                  // When you are done adding all the new faces, delete the old notes
                                  [self deleteOneNote];
                              }];
        }
    }
    else
    {
        blockOperation = [NSBlockOperation blockOperationWithBlock:^
                          {
                              MMFace *face = [_faceArray objectAtIndex: 0];
                              DDLogInfo (@"  BLOCK adding face uuid=%@", face.faceUuid);
                              [self addNoteForOneFace];
                          }];
    }
    [_stream.streamQueue addOperation: blockOperation];
}

- (void) deleteOneNote
{
    NSString *noteId = [_oldNotesToDelete objectAtIndex: 0];
    [_oldNotesToDelete removeObjectAtIndex: 0];
    [self deleteNote: noteId];
}

- (BOOL) findMatchingInIphotoLibraryByVersionUuidAndVersion
{
    // Try to find the matching object in the library
    if ((_version != -1) && _versionUuid)
    {
        NSNumber *number = [NSNumber numberWithInteger: _version - 1];
        NSString *query =  @"SELECT masterUuid, masterHeight, masterWidth, processedHeight, "
                                "processedWidth, rotation, imagePath, filename, versionUuid FROM RKVersion v"
                            "FROM RKVersion v JOIN RKMaster m ON m.uuid = v.masterUuid "
                            "WHERE uuid = ? AND versionNumber = ? ";
        NSArray *args = @[_versionUuid, number];

        FMResultSet *resultSet = [_stream.library.photosDatabase executeQuery: query
                                                         withArgumentsInArray: args];
        
        if (resultSet && [resultSet next])
        {
            [self updateFromIphotoLibraryVersionRecord: resultSet];
            
            NSString *masterPath = [resultSet stringForColumn: @"imagePath"];
            NSString *versionFilename = [resultSet stringForColumn: @"filename"];
            NSString *versionUuid = [resultSet stringForColumn: @"versionUuid"];

            _iPhotoOriginalImagePath = [_stream.library versionPathFromMasterPath: (NSString *) masterPath
                                                                      versionUuid: versionUuid
                                                                  versionFilename: versionFilename];
            return YES;
        }
    }
    return NO;
}

// Using the width, height and date (already acquired), look for a match
- (BOOL) findMatchingVersionInIphotoLibraryByAttributes
{
    
    // This process is problematic. Using the image dimensions and its original name,
    // we can find any number of matches. In some cases we may not have the name!
    // To narrow those down to the right image, it is necessary to find images
    // that have matching EXIF data or have the same byte length (when available).
    // In fact, we may find multiple matches and will have to take a guess
    // which is the best match.

    NSString *query = @"SELECT v.versionNumber version, v.uuid versionUuid, m.uuid, imagePath, v.filename filename, "
                             "masterUuid, masterHeight, masterWidth, processedHeight, processedWidth, "
                              "rotation, isOriginal "
                       "FROM RKVersion v JOIN RKMaster m ON m.uuid = v.masterUuid "
                       "WHERE m.isInTrash != 1 AND m.originalVersionName  = ? AND "
                             "v.processedWidth = ? AND v.processedHeight = ? "
                       "ORDER BY v.versionNumber DESC ";
            ;
    
    // TODO  See notes here
    
    NSString *width = [_flickrDictionary objectForKey: @"width"];
    NSString *height = [_flickrDictionary objectForKey: @"height"];
    if ((!_originalFilename) || (!width) || (!height))
    {
        // TODO Research in what cases these are unavailable.
        return NO;
    }
    NSArray *args = @[_originalFilename, width, height];
    FMResultSet *resultSet = [_stream.library.photosDatabase executeQuery: query
                                             withArgumentsInArray: args];

    NSString *flickrModifyTime = [_exifDictionary valueForKeyPath: @"IFD0.ModifyDate"];
    NSString *flickrOriginalTime = [_exifDictionary valueForKeyPath: @"ExifIFD.DateTimeOriginal"];

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
                exif = [_stream.library versionExifFromMasterPath: masterPath];
            }
            else
            {
                
                exif = [_stream.library versionExifFromMasterPath: masterPath
                                                      versionUuid: versionUuid
                                                  versionFilename: versionFilename];
            }
            
            if (exif)
            {
                NSString *iphotoModifyTime = [[exif objectForKey: @"{TIFF}"] valueForKey: @"DateTime"];
                NSString *iphotoOriginalTime = [[exif objectForKey: @"{Exif}"] valueForKey: @"DateTimeOriginal"];
                _iPhotoOriginalImagePath = [exif objectForKey: @"_image"];
                
                if ((iphotoModifyTime && [iphotoModifyTime isEqualToString: flickrModifyTime]) &&
                    (iphotoOriginalTime && [iphotoOriginalTime isEqualToString: flickrOriginalTime]))
                    
                {
                    _versionUuid = versionUuid;
                    _version = [[resultSet stringForColumn: @"version"] intValue];
                    [self updateFromIphotoLibraryVersionRecord: resultSet];
                    DDLogInfo(@"VERSION MATCH");
                    return YES;
                }
                DDLogInfo(@"POSS MATCH REJD iphotoModifyTime=%@, flickrModifyTime=%@, iphotoOriginalTime=%@, flickrOriginalTime=%@",
                            iphotoModifyTime, flickrModifyTime, iphotoOriginalTime, flickrOriginalTime);
            }
            else
            {
                DDLogWarn(@"NO MATCH FOUND");
                continue;
            }
        }
    }
    return NO;
}

- (void) setByteLength: (long long) length
{
    [_flickrDictionary setValue: @(length) forKey: @"bytes"];
    [_request releaseStrongPointers];
    _didFetchOriginalByteSize = YES;
    [self performNextStep];
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
        DDLogError(@"Failed to create center point(s) for crop or rotation");
    }
}

- (void) updateFromIphotoLibraryVersionRecord: (FMResultSet *) resultSet
{
    if (resultSet)
    {
        _masterUuid      = [resultSet stringForColumn: @"masterUuid"];
        _masterHeight    = (Float64)[resultSet intForColumn: @"masterHeight"];
        _masterWidth     = (Float64)[resultSet intForColumn: @"masterWidth"];
        _processedHeight = (Float64)[resultSet intForColumn: @"processedHeight"];
        _processedWidth  = (Float64)[resultSet intForColumn: @"processedWidth"];
        _rotationAngle   = (Float64)[resultSet intForColumn: @"rotation"];
    }
}

- (NSArray *) findRelevantAdjustments
{
    /* Be sure these are initialized each time */

    _croppedWidth = _processedWidth;
    _croppedHeight = _processedHeight;
    if (!self.versionUuid)
    {
        return nil;
    }

    FMDatabase *photosDb = [self.stream.library photosDatabase];
    if (photosDb)
    {
        NSArray *args = @[_versionUuid];
        NSString *adjQuerySql = @"SELECT * FROM RKImageAdjustment "
                                 "WHERE name IN ('RKCropOperation', 'RKStraightenCropOperation') "
                                 "AND isEnabled = 1 "
                                 "AND versionUuid = ? "
                                 "ORDER BY adjIndex";

        FMResultSet * adjustments = [photosDb executeQuery: adjQuerySql
                                      withArgumentsInArray: args];
        if (!adjustments)
        {
            DDLogError(@"    FMDB error=%@", [photosDb lastErrorMessage]);
            return nil;
        }

        BOOL hasCrop = NO;
        BOOL hasStraighten = NO;
        while ([adjustments next])
        {
            NSString *operationName = [adjustments stringForColumn: @"name"];
            DDLogInfo(@"ADJ FOUND     operationName=%@", operationName);

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
                        [_adjustmentsArray addObject: parameters];
                        NSNumber *operationVersion = [parameters valueForKey: @"DGOperationVersionNumber"];
                        if ([operationVersion intValue] != 0)
                        {
                            @throw [NSException exceptionWithName: @"UnexpectedOperationParameter"
                                                           reason: @"Unexpected Version Number ("
                                                         userInfo: parameters];
                        }
                        if ([operationName isEqualToString: @"RKCropOperation"])
                        {
                            NSInteger cw = [[parameters valueForKeyPath: @"inputKeys.inputWidth"] intValue];
                            NSInteger ch = [[parameters valueForKeyPath: @"inputKeys.inputHeight"] intValue];
                            
                            // I had a single occurrence of a crop operation coming through with settings of
                            // height=0 and width=0. Since apparently that might happen, this is a safety net
                            // to make sure there is no recurrence.
                            if ((cw > 0) && (ch > 0))
                            {
                                hasCrop = YES;
                                _croppedWidth =  cw;
                                _croppedHeight = ch;
                                Float64 x = (Float64) [[parameters valueForKeyPath: @"inputKeys.inputXOrigin"] intValue];
                                Float64 y = (Float64) [[parameters valueForKeyPath: @"inputKeys.inputYOrigin"] intValue];
                                _cropOrigin.x += x;
                                _cropOrigin.y += y;

                                DDLogInfo(@"SET CROP TO   cropOrigin=%@ %3.1fWx%3.1fH", _cropOrigin, _croppedWidth, _croppedHeight);
                            }
                        }
                        else if ([operationName isEqualToString: @"RKStraightenCropOperation"])
                        {
                            hasStraighten = YES;
                            NSString *angle = [parameters valueForKeyPath: @"inputKeys.inputRotation"];
                            _straightenAngle += [angle floatValue];

                            DDLogInfo(@"SET ROTATION  straigtenAngle=%3.1f", _straightenAngle);
                        }
                    }
                }
            }
        }
        
        // In the following case, the StraghtenCrop operation will have to do a crop, and it is
        // determined by measuring back from the center in each direction (by half).
        if (hasStraighten && !hasCrop)
        {
            DDLogInfo(@">>> BEFORE  cropOrigin=%@", _cropOrigin);

         /*  What follows ia bit of a mystery to my challenged brain
          
            When there is only a straighten operation, it's up to us to figure out where the 
            crop origin falls. For some reason, it's like we rotate the x one way and the y
            the other direction. , and from there we know where the origin is. This probably 
            relates to the fact that we're cropping to the minimum rectangle that fits. I suspect
            there is a more efficient way to get this done (much more, in fact) but at this point
            it is working and I'm going to bail.
          */
            
            MMPoint *rotateCenterPoint = [[MMPoint alloc] initWithX: (_masterWidth / 2.0) y: (_masterHeight / 2.0)];
            _cropOrigin.x =  (_masterWidth - _croppedWidth) / 2.0;
            _cropOrigin.y = (_masterHeight - _croppedHeight) / 2.0;
            [_cropOrigin rotate: fabs(_straightenAngle) relativeTo: rotateCenterPoint];
            Float64 correctX = _cropOrigin.x;

            _cropOrigin.x =  (_masterWidth - _croppedWidth) / 2.0;
            _cropOrigin.y = (_masterHeight - _croppedHeight) / 2.0;
            [_cropOrigin rotate: -fabs(_straightenAngle) relativeTo: rotateCenterPoint];
            _cropOrigin.x = correctX;

            DDLogInfo(@">>> AFTER   cropOrigin=%@", _cropOrigin);
            
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
        DDLogError(@"ERROR     Unable to allocate rotateCenterPoint");
        return nil;
    }
    BOOL quarterTurn = (rotationAngle == 90.0) || (rotationAngle == 270.0);

    if (!_masterUuid)
    {
        DDLogWarn(@"WARNING   Photo has no masterUuid");
        return nil;
    }

    FMDatabase *faceDb = [self.stream.library facesDatabase];
    if (!faceDb)
    {
        DDLogError(@"ERROR   No face database!");
        return nil;
    }

    NSArray *args = @[_masterUuid];
    NSUInteger matches = [[[self.stream library] facesDatabase]
                                intForQuery: @"SELECT COUNT(*) cnt FROM RKDetectedFace WHERE masterUuid = ?",
                                _masterUuid];

    if (matches > 0)
    {
        result = [[NSMutableArray alloc] initWithCapacity: matches];
        if (!result)
        {
            DDLogError(@"ERROR   No result returned by FMDatabase");
            return nil;
        }
        // TODO By counting rejected faces you can spot photos with large crowds where only one person matters
        FMResultSet *resultSet = [faceDb executeQuery: @"SELECT f.*, "
                                  "fn.name, fn.uuid faceNameUuid, fn.fullName, fn.keyVersionUuid FROM RKDetectedFace f "
                                  "LEFT JOIN RKFaceName fn ON f.faceKey = fn.faceKey "
                                  "WHERE masterUuid = ?"
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
            {
                DDLogInfo(@"GROW CANVAS   %3.1fWx%3.1fH", newWidth, newHeight);
            }
            
            while ([resultSet next])
            {
                
                MMPoint *topLeft     = [[MMPoint alloc] initWithX: [resultSet doubleForColumn: @"topLeftX" ]
                                                                y: [resultSet doubleForColumn: @"topLeftY" ]];
                MMPoint *bottomLeft  = [[MMPoint alloc] initWithX: [resultSet doubleForColumn: @"bottomLeftX" ]
                                                                y: [resultSet doubleForColumn: @"bottomLeftY" ]];
                MMPoint *bottomRight = [[MMPoint alloc] initWithX: [resultSet doubleForColumn: @"bottomRightX" ]
                                                                y: [resultSet doubleForColumn: @"bottomRightY" ]];
                NSInteger faceWidth = [resultSet intForColumn: @"width"];
                NSInteger faceHeight = [resultSet intForColumn: @"height"];


                MMFace *face = [[MMFace alloc] initFromIphotoWithTopLeft: topLeft
                                                              bottomLeft: bottomLeft
                                                             bottomRight: bottomRight
                                                               faceWidth: faceWidth
                                                              faceHeight: faceHeight
                                                                  ignore: [resultSet boolForColumn: @"ignore"]
                                                                rejected: [resultSet boolForColumn: @"rejected"]
                                                                faceUuid: [resultSet stringForColumn: @"uuid" ]
                                                                   photo: self];
                if (face)
                {
                    [face setName: [resultSet stringForColumn: @"name"]
                     faceNameUuid: [resultSet stringForColumn: @"faceNameUuid"]
                          faceKey: [resultSet intForColumn: @"faceKey"]
                   keyVersionUuid: [resultSet stringForColumn: @"keyVersionUuid"]
                           manual: [resultSet columnIsNull: @"faceFlags"]];

                    {
                        DDLogInfo(@"FACE DIMS     %3.1fWx%3.1fH", face.faceWidth, face.faceHeight);
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

                    {
                        DDLogInfo(@"ADJUSTED      centerPoint=%@", face.centerPoint);
                    }

                    BOOL visible = [face visibleWithCroppedWidth: cropWidth
                                                   croppedHeight: cropHeight];
                    {
                        DDLogInfo(@"SET VIS       visible=%d", visible);
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
    {
        DDLogInfo(@"FINAL SIZE    cropOrigin=%@ cropDims=%3.1fWx%3.1fH", cropOrigin, _masterWidth, _masterHeight);
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
    [self moveFacesRelativeToTopLeftOrigin];
    [self fetchThumbnailsFromOriginal];
    [self sendPhotoToMugmover];
    
    // Note that we discard the hidden/rejected faces _after_ uploading to mugmover.
    // This is not an error: we intentionally hold onto those.
    [self discardHiddenFaces];

    // TODO Some day we will reinstate the following line. When you do, be sure to look into
    // optimizing the note generation so that we don't keep deleting and adding the same notes.
    // Without that we will use up our API quota very quickly.

    // To restore Flickr note-writing, remove the next two operations. It's by virtual of
    // deleting all fo this data that we inhibit the Flickr note-writing.
    if (_oldNotesToDelete)
    {
        [_oldNotesToDelete removeAllObjects];
    }
    if (_faceArray)
    {
        [_faceArray removeAllObjects];
    }

    [self updateNotesOnFlickr];
}

- (void) moveFacesRelativeToTopLeftOrigin
{
    for (MMFace *face in _faceArray)
    {
        [face moveCenterRelativeToTopLeftOrigin];
    }
}
- (void) discardHiddenFaces
{
    NSMutableArray *discardedItems = [NSMutableArray array];
    
    for (MMFace *face in _faceArray)
    {
        if (!face.visible || face.rejected || face.ignore)
        {
            [discardedItems addObject: face];
        }
    }
    
    [_faceArray removeObjectsInArray: discardedItems];
    
}
- (BOOL) fetchThumbnailsFromOriginal
{
    if (_faceArray)
    {
        NSMutableArray *rectangles = [[NSMutableArray alloc] initWithCapacity: [_faceArray count]];
        for (MMFace *face in _faceArray)
        {
            // We want square images, so we settle on the average of the height/width
            // The automated faces are very tight, so we upscale the targeted dimension (* 3.0)
            Float64 idealDim = ((face.faceWidth + face.faceHeight) / 2.0) * 3.0;

            Float64 potentialX = MIN([face.centerPoint x],                       // dist between center of face and left side of photo
                                     _processedWidth - [face.centerPoint x]);    // dist between center of face and right side of photo
            Float64 potentialY = MIN([face.centerPoint y] ,                      // dist between center of face and bottom side of photo
                                     _processedHeight - [face.centerPoint y]);   // dist between center of face and top side of photo
            Float64 physicalLimit = 2.0 * MIN(potentialX, potentialY);           // 2 x the smallest of them all wins
            idealDim = MIN(idealDim, physicalLimit);                           // The smallest wins

            Float64 left = [face.centerPoint x] - (idealDim / 2.0);
            Float64 bottom = (_processedHeight - [face.centerPoint y]) - (idealDim / 2.0);
            
            NSArray *rect = @[[NSNumber numberWithDouble: left],
                              [NSNumber numberWithDouble: bottom], // OSX uses the bottom-left corner for origin
                              [NSNumber numberWithDouble: idealDim],
                              [NSNumber numberWithDouble: idealDim]];
            [rectangles addObject: rect];
        }
        if (_iPhotoOriginalImagePath)
        {
            NSMutableArray *thumbnails = [MMPhotoLibrary getCroppedRegions: _iPhotoOriginalImagePath
                                                           withCoordinates: rectangles
                                                                 thumbSize: 100]; // standardize on 100x100 thumbnails
            // TODO Need an assertion here
            if ([thumbnails count] != [_faceArray count])
            {
                DDLogError(@"ERROR expected %lu thumbnails, got %lu.", [_faceArray count], [thumbnails count]);
                return NO;
            }
            else
            {
                NSInteger counter = 0;
                for (MMFace *face in _faceArray)
                {
                    face.thumbnail = thumbnails[counter];
                    counter++;
                }
            }
        }
    }
    return YES;
}

- (void) sendPhotoToMugmover
{
    NSDictionary *properties = @{
                                 @"source":
                                    @{ @"app":                  @"mmu",
                                       @"appVersion": (NSString *) [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"],
                                       @"databaseUuid":         [[_stream library] databaseUuid],
                                       @"databaseVersion":      [[_stream library] databaseVersion],
                                       @"databaseAppId":        [[_stream library] databaseAppId],
                                     },
                                 @"crop":
                                    @{ @"cropOrigin":           [_cropOrigin asDictionary],
                                       @"croppedHeight":        [NSNumber numberWithLong: _croppedHeight],
                                       @"croppedWidth":         [NSNumber numberWithLong: _croppedWidth],
                                       @"rotationAngle":        [NSNumber numberWithDouble: _rotationAngle],
                                       @"straightenAngle":      [NSNumber numberWithDouble: _straightenAngle],
                                     },
                                 @"photo":
                                    @{ @"height":               [NSNumber numberWithLong: _masterHeight],
                                       @"number":               [NSNumber numberWithLong: _version],
                                       @"masterUuid":           _masterUuid,
                                       @"originalDate":         _originalDate ? _originalDate : @"",
                                       @"originalFilename":     _originalFilename ? _originalFilename : @"",
                                       @"versionUuid":          _versionUuid,
                                       @"width":                [NSNumber numberWithLong: _masterWidth],
                                    },
                                 @"service":                     _flickrDictionary,
                                 @"adjustments":                 _adjustmentsArray,
                               };
    

    NSMutableDictionary *attributes = [properties mutableCopy];


    if (_faceArray)
    {
        NSMutableArray *facesProperties = [[NSMutableArray alloc] initWithCapacity: [_faceArray count]];
        for (MMFace *face in _faceArray)
        {
            [facesProperties addObject: [face properties]];

        }
        [attributes setObject: facesProperties forKey: @"faces"];
    }

    // Now that we have everything, serialize the data to JSON and start the upload
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject: attributes
                                                       options: 0
                                                         error: &error];
    if (!jsonData)
    {
        DDLogError(@"ERROR JSON Serialization returned: %@", error);
    }
    else
    {
        NSString *jsonString = [[NSString alloc] initWithData: jsonData encoding: NSUTF8StringEncoding];
        NSDictionary *postData = @{@"data": jsonString};
        DDLogInfo(@"TO MUGMOVER   index=%ld, remaining=%ld", (long)_index, [_stream inQueue]);
        _apiRequest = [[MMApiRequest alloc] initUploadForApiVersion: 1
                                                           bodyData: postData];
    }

}

- (void) releaseStrongPointers
{
    if (_flickrRequest)
    {
        [_stream.requestPool returnRequestToPool: _flickrRequest];
    }
    _adjustmentsArray = nil;
    _apiRequest = nil;
    _cropOrigin = nil;
    _exifDictionary = nil;
    _faceArray = nil;
    _flickrDictionary = nil;
    _flickrRequest = nil;
    _masterUuid = nil;
    _oldNotesToDelete = nil;
    _originalDate = nil;
    _originalFilename = nil;
    _originalUrl = nil;
    _request = nil;
    _versionUuid = nil;
    [_stream removeFromPhotoDictionary: self];
}

- (NSString *) title
{
    NSString *title = [self.flickrDictionary  objectForKey: @"title"];
    if (![title length])
    {
        title = @"No title";
    }
    return title;
}

- (void) fetchImageByteSize
{
    
    _request = [[MMNetworkRequest alloc] initMakeHeadRequest: _originalUrl
                                                    delegate: self];
    
}

- (void) fetchFlickrSizes
{
    if ([_flickrRequest isRunning])
    {
        NSString *message = [NSString stringWithFormat: @"Pool request is still running, sessionInfo=%@",
                                                        _flickrRequest.sessionInfo ];
        @throw [NSException exceptionWithName: @"PoolManagement"
                                       reason: message
                                     userInfo: nil];
    }

    NSString *photoId = [_flickrDictionary valueForKey: @"id"];
    NSString *secret = [_flickrDictionary valueForKey: @"secret"];
    _flickrRequest.sessionInfo = @"fetchSizes";

    [_flickrRequest callAPIMethodWithGET: @"flickr.photos.getSizes"
                               arguments: [NSDictionary dictionaryWithObjectsAndKeys: photoId, @"photo_id",
                                           secret, @"secret",
                                           nil]];
    
}

- (void) fetchFlickrInfo
{
    if ([_flickrRequest isRunning])
    {
        NSString *message = [NSString stringWithFormat: @"Pool request is still running, sessionInfo=%@",
                             _flickrRequest.sessionInfo ];
        @throw [NSException exceptionWithName: @"PoolManagement"
                                       reason: message
                                     userInfo: nil];
    }
    
    _flickrRequest.sessionInfo = @"fetchInfo";
    NSString *photoId = [_flickrDictionary objectForKey: @"id"];
    NSString *secret = [_flickrDictionary objectForKey: @"secret"];
    [_flickrRequest callAPIMethodWithGET: @"flickr.photos.getInfo"
                               arguments: [NSDictionary dictionaryWithObjectsAndKeys: photoId, @"photo_id",
                                           secret, @"secret",
                                           nil]];
    
}

- (void) fetchFlickrExif
{
    if ([_flickrRequest isRunning])
    {
        NSString *message = [NSString stringWithFormat: @"Pool request is still running, sessionInfo=%@",
                             _flickrRequest.sessionInfo ];
        @throw [NSException exceptionWithName: @"PoolManagement"
                                       reason: message
                                     userInfo: nil];
    }
    
    _flickrRequest.sessionInfo = @"fetchExif";
    NSString *photoId = [_flickrDictionary objectForKey: @"id"];
    NSString *secret = [_flickrDictionary objectForKey: @"secret"];
    [_flickrRequest callAPIMethodWithGET: @"flickr.photos.getExif"
                              arguments: [NSDictionary dictionaryWithObjectsAndKeys: photoId, @"photo_id",
                                          secret, @"secret",
                                          nil]];
    
}

- (void) addNoteForOneFace
{
    // We add the first face in the faceArray
    MMFace *face = [_faceArray objectAtIndex: 0];

    if ([_flickrRequest isRunning])
    {
        NSString *message = [NSString stringWithFormat: @"Pool request is still running, sessionInfo=%@",
                             _flickrRequest.sessionInfo ];
        @throw [NSException exceptionWithName: @"PoolManagement"
                                       reason: message
                                     userInfo: nil];
    }
    _flickrRequest.sessionInfo = @"addNote";

    // add a note for this face
    NSDictionary *args = @{@"photo_id": [_flickrDictionary valueForKey: @"id"],
                           @"note_x": face.flickrNoteX,
                           @"note_y": face.flickrNoteY,
                           @"note_w": face.flickrNoteWidth,
                           @"note_h": face.flickrNoteHeight,
                           @"note_text": face.flickrNoteText,
                           @"api_key": MUGMOVER_API_KEY_MACRO,
                           };
    [_flickrRequest callAPIMethodWithPOST: @"flickr.photos.notes.add"
                               arguments: args];

}

- (void) deleteNote: (NSString *) noteId
{
    if ([_flickrRequest isRunning])
    {
        NSString *message = [NSString stringWithFormat: @"Pool request is still running, sessionInfo=%@",
                             _flickrRequest.sessionInfo ];
        @throw [NSException exceptionWithName: @"PoolManagement"
                                       reason: message
                                     userInfo: nil];
    }
    NSArray  *pieces = @[@"deleteNote", noteId];
    _flickrRequest.sessionInfo = [pieces componentsJoinedByString: @";"];
    
    NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys: noteId, @"note_id",
                          MUGMOVER_API_KEY_MACRO, @"api_key",
                          nil];
    [_flickrRequest callAPIMethodWithPOST: @"flickr.photos.notes.delete"
                               arguments: args];
}


#pragma mark ObjectiveFlickr delegate methods

- (void) flickrAPIRequest: (OFFlickrAPIRequest *) inRequest
  didCompleteWithResponse: (NSDictionary *) inResponseDictionary
{
    DDLogInfo(@"RESP RECEIVED request=%@", inRequest.sessionInfo);
    NSArray *pieces = [inRequest.sessionInfo componentsSeparatedByString: @";"];

    if ([pieces[0] isEqualToString: @"fetchExif"])
    {
        NSArray *exifArray = [inResponseDictionary valueForKeyPath: @"photo.exif"];
        for (NSDictionary *dict in exifArray)
        {
            NSString *tag = [dict objectForKey: @"tag"];
            NSString *tagspace = [dict objectForKey: @"tagspace"];
            NSDictionary *raw = [dict objectForKey: @"raw"];
            
            NSDictionary *spaceDictionary = [_exifDictionary objectForKey: tagspace];
            if (!spaceDictionary)
            {
                spaceDictionary = [[NSMutableDictionary alloc] init];
                [_exifDictionary setObject: spaceDictionary forKey: tagspace];
            }
            [spaceDictionary setValue: [raw valueForKey: @"_text"] forKey: tag];
        }

        // Store some things you will need later
        _originalFilename = [_exifDictionary valueForKeyPath: @"IPTC.ObjectName"];
        _originalDate = [_exifDictionary valueForKeyPath: @"ExifIFD.DateTimeOriginal"];
        
        // The versionUuid might be in one of two places. Check one if the other isn't there.
        _versionUuid = [_exifDictionary valueForKeyPath: @"IPTC.SpecialInstructions"];
        if (!_versionUuid)
        {
            _versionUuid = [_exifDictionary valueForKeyPath: @"XMP-photoshop.Instructions"];
        }
        NSObject *versionObject = [_exifDictionary valueForKeyPath: @"IPTC.ApplicationRecordVersion"];
        _version = (versionObject) ? [(NSString *) versionObject integerValue] : -1;

        _didFetchExif = YES;
        [self performNextStep];
    }
    else if ([pieces[0] isEqualToString: @"fetchInfo"])
    {
        NSString *originalSecret = [inResponseDictionary valueForKeyPath: @"photo.originalsecret"];
        NSString *originalFormat = [inResponseDictionary valueForKeyPath: @"photo.originalformat"];
        NSString *dateUploaded = [inResponseDictionary valueForKeyPath: @"photo.dateuploaded"];
        if (dateUploaded)
        {
            [_flickrDictionary setValue: [NSNumber numberWithUnsignedLong: [dateUploaded longLongValue]]
                                 forKey: @"dateUploaded"];
        }

        if (originalSecret && originalFormat)
        {
            _originalUrl = [NSString stringWithFormat: @"https://farm%@.staticflickr.com/%@/%@_%@_o.%@",
                                        [_flickrDictionary valueForKey: @"farm"],
                                        [_flickrDictionary valueForKey: @"server"],
                                        [_flickrDictionary valueForKey: @"id"],
                                        originalSecret,
                                        originalFormat];
            [_flickrDictionary setValue: originalFormat
                                 forKey: @"originalFormat"];
        }
        else
        {
            // If we can't get the original URL, bypass this step
            _didFetchOriginalByteSize = YES;
        }
        /* CAUTION: FetchInfo operation implies all the mugmover notes will be deleted. */
        NSArray *noteArray = [inResponseDictionary valueForKeyPath: @"photo.notes.note"];
        if (noteArray)
        {
            for (NSDictionary *dict in noteArray)
            {
                NSString *noteId = [dict objectForKey: @"id"];
                NSString *noteText = [dict valueForKey: @"_text"];
                if (noteText)
                {
                    NSRange result = [noteText rangeOfString: @"mugmover" options: NSCaseInsensitiveSearch];
                    if (result.location != NSNotFound)
                    {
                        [_oldNotesToDelete addObject: noteId];
                    }
                }
            }
        }
        _didFetchInfo = YES;
        [self performNextStep];
    }
    else if ([pieces[0] isEqualToString: @"fetchSizes"])
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
                        [_flickrDictionary setValue: [NSNumber numberWithInteger: [widthString integerValue]]
                                             forKey: @"width"];
                        [_flickrDictionary setValue: [NSNumber numberWithInteger: [heightString integerValue]]
                                             forKey: @"height"];
                    }
                }
            }
        }
        _didFetchSizes = YES;
        [self performNextStep];
    }
    else if ([pieces[0] isEqualToString: @"deleteNote"])
    {
        [self updateNotesOnFlickr]; // There is no cleanup because we delete the notes as we queue the requests
    }
    
    else if ([pieces[0] isEqualToString: @"addNote"])
    {
        // We can now remove the face.
        MMFace *face = [_faceArray objectAtIndex: 0];
        [face releaseStrongPointers];
        [_faceArray removeObjectAtIndex: 0];
        [self updateNotesOnFlickr];
    }
}

- (void) flickrAPIRequest: (OFFlickrAPIRequest *) inRequest
         didFailWithError: (NSError *) inError
{
    DDLogError(@"      FAILED: request=%@", inRequest.sessionInfo);
    BOOL retryable = [_stream trackFailedAPIRequest: inRequest
                                              error: inError];
    NSArray *pieces = [inRequest.sessionInfo componentsSeparatedByString: @";"];

    if (retryable)
    {
        if ([pieces[0] isEqualToString: @"fetchSizes"])
        {
            [self fetchFlickrSizes];
        }
        else if ([pieces[0] isEqualToString: @"fetchExif"])
        {
            [self fetchFlickrExif];
        }
        else if ([pieces[0] isEqualToString: @"fetchInfo"])
        {
            [self fetchFlickrInfo];
        }
        else if ([pieces[0] isEqualToString: @"deleteNote"])
        {
            if (inError.code == 1) // Note not found
            {
                // TODO IMPORTANT! Reproduce this error to make sure it actually is the right error code
                // TODO Log the error
                // Do not retry
                [self updateNotesOnFlickr]; // Get the next one
            }
            else
            {
                [self deleteNote: pieces[1]]; // Retry
            }
        }
        
        else if ([pieces[0] isEqualToString: @"addNote"])
        {
            // This will try to add the same note, but do it outside the delegate method
            [self updateNotesOnFlickr];
            
        }

    }
    else
    {
        // TODO Report you are giving up.
        DDLogError(@"ABANDONING  Unable to process request %@", pieces[0]);
        if ([pieces[0] isEqualToString: @"deleteNote"])
        {
            // If you are giving up on deleting a note, queue the next one.
            // This is important as eventually that is what will release the photo object itself.
            [self updateNotesOnFlickr]; // Get the next one
        }
        //
        else if ([pieces[0] isEqualToString: @"addNote"])
        {
            // If you can't add the note, blow it away and try the next one
            MMFace *face = [_faceArray objectAtIndex: 0];
            [face releaseStrongPointers];
            [_faceArray removeObjectAtIndex: 0];
            [self updateNotesOnFlickr];
        }
        // Need to do all the release stuff you do on the corresponding success event.
        else
        {
            [self releaseStrongPointers];
        }
    }
}

- (void) mmNetworkRequest: (MMNetworkRequest *) request
  didCompleteWithResponse: (NSDictionary *) responseDictionary
{
}

- (void) mmNetworkRequest: (MMNetworkRequest *) request
         didFailWithError: (NSError *) error
{
    DDLogError(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey: NSURLErrorFailingURLStringErrorKey]);
    if (![_request retryable])
    {
        [self performNextStep];
    }

}
@end