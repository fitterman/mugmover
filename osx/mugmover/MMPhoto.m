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
#import "MMApiRequest.h"
#import "MMFlickrPhotostream.h"
#import "MMFlickrRequest.h"
#import "MMFlickrRequestPool.h"
#import "MMPhoto.h"
#import "MMPhotolibrary.h"
#import "MMPoint.h"
#import "MMFace.h"
#import "MMEnvironment.h"
#import "MMNetworkRequest.h"

@implementation MMPhoto

- (MMPhoto *) initWithFlickrDictionary: (NSDictionary *)flickrDictionary
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
            _exifDictionary = [NSMutableDictionary new];
            _oldNotesToDelete = [[NSMutableArray alloc] init];
            _flickrRequest = [_stream.requestPool getRequestFromPoolSettingDelegate: self];

            _didFetchExif = NO;
            _didFetchInfo = NO;
            _didFetchOriginalByteSize = NO;
            _didFetchSizes = NO;
            _didProcessPhoto = NO;
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
    NSLog(@" performNextStep %lx exif=%hhd info=%hhd sizes=%hhd byteSize=%hhd processed=%hhd",
          (NSInteger) self,
          _didFetchExif, _didFetchInfo, _didFetchSizes, _didFetchOriginalByteSize,
          _didProcessPhoto);
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
        NSLog(@"Succeeded");
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
    else if (!_didProcessPhoto)                                    // FINALLY, process the image
    {
        if ([self findMatchingInIphotoLibraryByVersionUuidAndVersion] ||
            [self findMatchingVersionInIphotoLibraryByAttributes])
        {
            [self processPhoto]; // This calls sendPhotoToMugMover and updateNotesOnFlickr
        }
        else
        {
            NSLog(@"ORPHAN PHOTO    "); // TODO Figure out what to do with this.
            // TODO May want to start deleting any mugmover comments as a cleanup step.
            // If so, call [self updateNotesOnFlickr]] but not sure about that.
        }
        _didProcessPhoto = YES;
    }
    else
    {
        NSLog(@"processPhoto was called an extra time!");
    }
}

- (void) updateNotesOnFlickr
{
    NSBlockOperation *blockOperation;
    if ((!_faceArray) || ([_faceArray count] == 0))
    {
        if ([_oldNotesToDelete count] == 0)
        {
            // Get the stream pointer before you blow it away
            [self releaseStrongPointers];
            [_stream removeFromPhotoDictionary: self];
        }
        else
        {
            blockOperation = [NSBlockOperation blockOperationWithBlock:^
                              {
                                  // When you are done adding all the new faces, delete the old notes
                                  [self deleteOneNote];
                              }];
            [_stream.streamQueue addOperation: blockOperation];
        }
    }
    else
    {
        blockOperation = [NSBlockOperation blockOperationWithBlock:^
                          {
                              MMFace *face = [_faceArray objectAtIndex: 0];
                              NSLog (@"  BLOCK adding face uuid=%@", face.faceUuid);
                              [self addNoteForOneFace];
                          }];
        [_stream.streamQueue addOperation: blockOperation];
    }
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
        NSArray *args = @[_versionUuid, number];
        
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
- (BOOL) findMatchingVersionInIphotoLibraryByAttributes
{
    
    // This process is problematic. Using the image dimensions and its original name,
    // we can find any number of matches. In some cases we may not have the name!
    // To narrow those down to the right image, it is necessary to find images
    // that have matching EXIF data or have the same byte length (when available).
    // In fact, we may find multiple matches and will have to take a guess
    // which is the best match.

    NSString *query = @"SELECT v.versionNumber version, v.uuid versionUuid, m.uuid, imagePath, v.filename filename, "
                             "masterUuid, masterHeight, masterWidth, rotation, isOriginal "
                       "FROM RKVersion v JOIN RKMaster m ON m.uuid = v.masterUuid "
                       "WHERE m.isInTrash != 1 AND m.originalVersionName  = ? AND "
                             "v.processedWidth = ? AND v.processedHeight = ? "
                       "ORDER BY v.versionNumber DESC ";
            ;
    
    // TODO: See notes here
    // TODO ## Make sure the originalFilename is used only when it is available;
    // TODO ## Use the width/height only when those are available. (Flickr users may restrict their availability.)
    
    NSString *width = [_flickrDictionary objectForKey: @"width"];
    NSString *height = [_flickrDictionary objectForKey: @"height"];
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
        }
    }
    return NO;
}

- (void) setByteLength: (long long) length
{
    [_flickrDictionary setValue: @(length) forKey: @"bytes"];
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
                        NSNumber *operationVersion = [parameters valueForKey: @"DGOperationVersionNumber"];
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

    NSArray *args = @[_masterUuid];
    NSUInteger matches = [[[self.stream library] facesDatabase]
                                intForQuery:@"SELECT COUNT(*) cnt FROM RKDetectedFace WHERE masterUuid = ?",
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
            if (MMdebugging)
            {
                NSLog(@"GROW CANVAS   %3.1fWx%3.1fH", newWidth, newHeight);
            }
            
            while ([resultSet next])
            {
                
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
                                                                  ignore: [resultSet boolForColumn: @"ignore"]
                                                                rejected: [resultSet boolForColumn: @"rejected"]
                                                                faceUuid: [resultSet stringForColumn:@"uuid" ]
                                                                   photo: self];
                if (face)
                {
                    [face setName: [resultSet stringForColumn: @"name"]
                     faceNameUuid: [resultSet stringForColumn: @"faceNameUuid"]
                          faceKey: [resultSet intForColumn: @"faceKey"]
                   keyVersionUuid: [resultSet stringForColumn: @"keyVersionUuid"]];

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

                    BOOL visible = [face visibleWithCroppedWidth: cropWidth
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
    [self sendPhotoToMugmover];
    [self discardHiddenFaces];
    [self updateNotesOnFlickr];
}

- (void) discardHiddenFaces
{
    NSMutableArray *discardedItems = [NSMutableArray array];
    
    for (MMFace *face in _faceArray) {
        if (!face.visible || face.rejected || face.ignore)
        {
            [discardedItems addObject: face];
        }
    }
    
    [_faceArray removeObjectsInArray: discardedItems];
    
}

- (void) sendPhotoToMugmover
{
    NSDictionary *properties = @{
                                 @"source":
                                    @{ @"app":                  @"mmu",
                                       @"appVersion": (NSString *) [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
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
                                 @"master":
                                    @{ @"height":               [NSNumber numberWithLong: _masterHeight],
                                       @"uuid":                 _masterUuid,
                                       @"width":                [NSNumber numberWithLong: _masterWidth],
                                     },
                                 @"version":
                                    @{ @"number":               [NSNumber numberWithLong: _version],
                                       @"uuid":                 _versionUuid,
                                    },
                                 @"flickr":                     _flickrDictionary,
                                 @"originalDate":               _originalDate,
                                 @"originalFilename":           _originalFilename ? _originalFilename : @"",
                               };
    

    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
    [attributes setObject: properties forKey: @"properties"];


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
    if (!jsonData) {
        NSLog(@"JSON Serialization returned an error: %@", error);
    } else {
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        NSDictionary *postData = @{@"data": jsonString};
        NSLog(@"Uploading Data");
        _apiRequest = [[MMApiRequest alloc] initUploadForApiVersion: 1
                                                           bodyData: postData];
    }

}

- (void)releaseStrongPointers
{
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

- (void) fetchImageByteSize
{
    
    _request = [[MMNetworkRequest alloc] initMakeHeadRequest: _originalUrl
                                                    delegate: self];
    
}

- (void) fetchFlickrSizes
{
    NSLog(@" entering fetchFlickrSizes");
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

- (void)deleteNote: (NSString *)noteId
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

- (void)flickrAPIRequest: (OFFlickrAPIRequest *)inRequest
 didCompleteWithResponse: (NSDictionary *)inResponseDictionary
{
    NSLog(@"  COMPLETION: request=%@", inRequest.sessionInfo);
    NSArray *pieces = [inRequest.sessionInfo componentsSeparatedByString:@";"];

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
        _version = (versionObject) ? [(NSString *)versionObject integerValue] : -1;

        _didFetchExif = YES;
        [self performNextStep];
    }
    else if ([pieces[0] isEqualToString: @"fetchInfo"])
    {
        NSString *originalSecret = [inResponseDictionary valueForKeyPath: @"photo.originalsecret"];
        NSString *originalFormat = [inResponseDictionary valueForKeyPath: @"photo.originalformat"];
        if (originalSecret && originalFormat)
        {
            _originalUrl = [NSString stringWithFormat:@"https://farm%@.staticflickr.com/%@/%@_%@_o.%@",
                                        [_flickrDictionary valueForKey: @"farm"],
                                        [_flickrDictionary valueForKey: @"server"],
                                        [_flickrDictionary valueForKey: @"id"],
                                        originalSecret,
                                        originalFormat];
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
                        [_flickrDictionary setValue: widthString forKey: @"width"];
                        [_flickrDictionary setValue: heightString forKey: @"height"];
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

- (void)flickrAPIRequest: (OFFlickrAPIRequest *)inRequest
        didFailWithError: (NSError *)inError
{
    NSLog(@"      FAILED: request=%@", inRequest.sessionInfo);
    BOOL retryable = [_stream trackFailedAPIRequest: inRequest
                                              error: inError];
    NSArray *pieces = [inRequest.sessionInfo componentsSeparatedByString:@";"];

    if (retryable)
    {
        if ([pieces[0] isEqualToString: @"fetchSizes"])
        {
            NSLog(@" Failed @");
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
        NSLog(@"  DEFEATED   Unable to process request %@", pieces[0]);
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
    }
}

- (void) mmNetworkRequest: (MMNetworkRequest *) request
  didCompleteWithResponse: (NSDictionary *) responseDictionary
{
}

- (void) mmNetworkRequest: (MMNetworkRequest *) request
         didFailWithError: (NSError *)error
{
    NSLog(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
    if (![_request retryable])
    {
        [self performNextStep];
    }

}
@end