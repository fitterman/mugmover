
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
#import "MMNetworkRequest.h"
#import "MMOauthFlickr.h"
#import "MMPhoto.h"
#import "MMPhotolibrary.h"
#import "MMPoint.h"
#import "MMEnvironment.h"
#import "MMNetworkRequest.h"
#import "MMDataUtility.h"

@import QuartzCore.CIFilter;
@import QuartzCore.CoreImage.CIContext;
@import QuartzCore.CoreImage.CIFilter;

#define MAX_THUMB_DIM (100)

extern NSInteger const MMDefaultRetries;
extern Float64 const MMDegreesPerRadian;

@implementation MMPhoto

- (MMPhoto *) commonInitialization
{
    _rotationAngle = 0.0;
    _straightenAngle = 0.0;
    _cropOrigin = [[MMPoint alloc] initWithX: 0.0 y: 0.0];
    if (!_cropOrigin)
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
    return self;
}

- (MMPhoto *) initFromPhotoProperties: (NSDictionary *) photoProperties
                       exifProperties: (NSMutableDictionary *) exifProperties
                              library: (MMPhotoLibrary *) library
{
    self = [self init];
    if (self)
    {
        if ([self commonInitialization] == nil)
        {
            [self releaseStrongPointers];
            return nil;
        }
    }
    _library = library;
    _verboseLogging = _library.verboseLogging;
    
    _masterUuid = [photoProperties valueForKey: @"masterUuid"];
    _masterHeight = [[photoProperties valueForKey: @"masterHeight"] doubleValue];
    _masterWidth = [[photoProperties valueForKey: @"masterWidth"] doubleValue];
    _processedHeight = [[photoProperties valueForKey: @"processedHeight"] doubleValue];
    _processedWidth = [[photoProperties valueForKey: @"processedWidth"] doubleValue];
    _rotationAngle = [[photoProperties valueForKey: @"rotation"] doubleValue];
    _versionUuid = [photoProperties valueForKey: @"versionUuid"];
    _version = [[photoProperties valueForKey: @"versionNumber"] longValue];
    _iPhotoOriginalImagePath = [exifProperties valueForKey: @"_image"];
    
    [self populateDateFromExif: exifProperties];

    _attributes = [[NSMutableDictionary alloc] initWithCapacity: 20];
    [_attributes setObject: [_library sourceDictionary] forKey: @"source"];
    [exifProperties removeObjectForKey: @"_image"];
    [_attributes setObject: exifProperties forKey: @"exif"];
    [_attributes setObject: [photoProperties mutableCopy] forKey: @"photo"];
    
    return self;
}

- (void) populateDateFromExif: (NSDictionary *) exifProperties
{    
    NSString *exifDateString;
    for (NSString *keypath in @[@"Exif.DateTimeOriginal", @"Exif.DateTimeDigitized", @"TIFF.DateTime"])
    {
        exifDateString = [exifProperties valueForKeyPath: keypath];
        if (exifDateString)
        {
            break;
        }
    }
    
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat: @"yyyy-MM-dd HH:mm:ss"];
    dateFormat.timeZone = [NSTimeZone timeZoneWithName: @"UTC"];

    if (exifDateString)
    {
        NSDate *exifDateTimestamp = nil;
        for (NSDateFormatter *exifDateFormat in [_library exifDateFormatters])
        {
            exifDateTimestamp = [exifDateFormat dateFromString: exifDateString];
            if (exifDateTimestamp)
            {
                _originalDate = [dateFormat stringFromDate: exifDateTimestamp];
                break;
            }
        }
    }
}

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
            _library = stream.library;
            if ([self commonInitialization] == nil)
            {
                [self releaseStrongPointers];
                return nil;
            }
            [_flickrDictionary addEntriesFromDictionary: flickrDictionary];
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
    // This structure forces the processing to happen serially, with the state being
    // maintained in this class.

    if (!_didFetchExif)                     // STEP 1: Get the Exif data from Flickr
    {
        [self fetchFlickrExif];
    }
    else if (!_didFetchInfo)                // STEP 2: Perform the getInfo call to get the notes
    {
        [self fetchFlickrInfo];
    }
    else if (!_didFetchSizes)               // STEP 3: Get the images sizes in hopes of accessing the original image
    {
        [self fetchFlickrSizes];
    }
    else if (!_didFetchOriginalByteSize)    // STEP 4: Retrieve the size of the original image
    {
        [self fetchImageByteSize];
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
/*
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
                              if (_library.verboseLogging)
                              {
                                  DDLogInfo (@"  BLOCK adding face uuid=%@", face.faceUuid);
                              }
                              [self addNoteForOneFace];
                          }];
    }
    [_stream.streamQueue addOperation: blockOperation];
*/
}

- (void) deleteOneNote
{
/*
    NSString *noteId = [_oldNotesToDelete objectAtIndex: 0];
    [_oldNotesToDelete removeObjectAtIndex: 0];
    [self deleteNote: noteId];
*/
}

- (BOOL) findMatchingInIphotoLibraryByVersionUuidAndVersion
{
    // Try to find the matching object in the library
    if ((_version != -1) && _versionUuid)
    {
        NSNumber *number = [NSNumber numberWithInteger: _version - 1];
        NSString *query =  @"SELECT masterUuid, masterHeight, masterWidth, processedHeight, "
                                "processedWidth, rotation, imagePath, v.fileName versionFilename, "
                                "v.name versionName, versionUuid "
                            "FROM RKVersion v JOIN RKMaster m ON m.uuid = v.masterUuid "
                            "WHERE uuid = ? AND versionNumber = ? ";
        NSArray *args = @[_versionUuid, number];

        FMResultSet *resultSet = [_library.photosDatabase executeQuery: query
                                                         withArgumentsInArray: args];

        if (resultSet && [resultSet next])
        {
            [self updateFromIphotoLibraryVersionRecord: resultSet];

            NSString *masterPath = [resultSet stringForColumn: @"imagePath"];            
            NSString *versionFilename = [resultSet stringForColumn: @"versionFilename"];
            NSString *versionName = [resultSet stringForColumn: @"versionName"];
            NSString *versionUuid = [resultSet stringForColumn: @"versionUuid"];

            _iPhotoOriginalImagePath = [_library versionPathFromMasterPath: (NSString *) masterPath
                                                                      versionUuid: versionUuid
                                                                  versionFilename: versionFilename
                                                                      versionName: versionName];
            [resultSet close];
            return YES;
        }
        [resultSet close];
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

    NSString *query = @"SELECT v.versionNumber version, v.uuid versionUuid, m.uuid, imagePath, v.name versionFilename, "
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
    FMResultSet *resultSet = [_library.photosDatabase executeQuery: query
                                             withArgumentsInArray: args];

    NSString *flickrModifyTime = [_exifDictionary valueForKeyPath: @"IFD0.ModifyDate"];
    NSString *flickrOriginalTime = [_exifDictionary valueForKeyPath: @"ExifIFD.DateTimeOriginal"];

    if (resultSet)
    {
        while ([resultSet next])
        {
            NSDictionary *exif = nil;

            NSString *masterPath = [resultSet stringForColumn: @"imagePath"];
            NSString *versionFilename = [resultSet stringForColumn: @"versionFilename"];
            NSString *versionName = [resultSet stringForColumn: @"versionName"];
            NSString *versionUuid = [resultSet stringForColumn: @"versionUuid"];

            if ([resultSet boolForColumn: @"isOriginal"])
            {
                exif = [_library versionExifFromMasterPath: masterPath];
            }
            else
            {

                exif = [_library versionExifFromMasterPath: masterPath
                                               versionUuid: versionUuid
                                           versionFilename: versionFilename
                                               versionName: versionName];
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
        [resultSet close];
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

    FMDatabase *photosDb = [_library photosDatabase];
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
            if (_library.verboseLogging)
            {
                DDLogInfo(@"ADJ FOUND     operationName=%@", operationName);
            }
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
                                if (_library.verboseLogging)
                                {
                                    DDLogInfo(@"SET CROP TO   cropOrigin=%@ %3.1fWx%3.1fH", _cropOrigin, _croppedWidth, _croppedHeight);
                                }
                            }
                        }
                        else if ([operationName isEqualToString: @"RKStraightenCropOperation"])
                        {
                            hasStraighten = YES;
                            NSString *angle = [parameters valueForKeyPath: @"inputKeys.inputRotation"];
                            _straightenAngle += [angle floatValue];
                            if (_library.verboseLogging)
                            {
                                DDLogInfo(@"SET ROTATION  straigtenAngle=%3.1f", _straightenAngle);
                            }
                        }
                    }
                }
            }
        }
        [adjustments close];

        // In the following case, the StraghtenCrop operation will have to do a crop, and it is
        // determined by measuring back from the center in each direction (by half).
        if (hasStraighten && !hasCrop)
        {

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

    FMDatabase *faceDb = [_library facesDatabase];
    if (!faceDb)
    {
        DDLogError(@"ERROR   No face database!");
        return nil;
    }

    NSArray *args = @[_masterUuid];
    NSUInteger matches = [[_library facesDatabase]
                                intForQuery: @"SELECT COUNT(*) cnt FROM RKDetectedFace WHERE masterUuid = ?",
                                _masterUuid];

    result = [[NSMutableArray alloc] initWithCapacity: matches]; // Even if it's zero, you have to send back an array

    if (matches > 0)
    {
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

            Float64 absStraightenAngleInRadians = fabs(straightenAngle) / MMDegreesPerRadian;
            Float64 newWidth =  (_masterWidth * cos(absStraightenAngleInRadians)) +
                                (_masterHeight * sin(absStraightenAngleInRadians));
            Float64 newHeight = (_masterHeight * cos(absStraightenAngleInRadians)) +
                                (_masterWidth * sin(absStraightenAngleInRadians));
            if (_library.verboseLogging)
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
                    if (_library.verboseLogging)
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

                    BOOL visible = [face visibleWithCroppedWidth: _processedWidth
                                                   croppedHeight: _processedHeight];
                    // If it isn't visible, drop it
                    if (visible)
                    {
                        [result addObject: face];
                    }
                    if (_library.verboseLogging)
                    {
                        DDLogInfo(@"ADJUSTED      face.centerPoint=%@", face.centerPoint);
                        DDLogInfo(@"SET VIS       visible=%d", visible);
                    }
                }
            }
            [resultSet close];
        }
    }
    if (_library.verboseLogging)
    {
        DDLogInfo(@"FINAL SIZE    cropOrigin=%@ cropDims=%3.1fWx%3.1fH", cropOrigin,
                  _processedWidth, _processedHeight);
    }
    return result;

}

- (Float64) aspectRatio
{
    return _processedWidth / _processedHeight;
}

- (void) processPhoto
{
    @autoreleasepool {
        [self findRelevantAdjustments];
        [self adjustForStraightenCropAndGetFaces];
        [self moveFacesRelativeToTopLeftOrigin];

        NSURL* fileUrl = [NSURL fileURLWithPath : _iPhotoOriginalImagePath];
        _thumbnail = @""; // It cannot be null, so just in case this fails.
        
        if (fileUrl)
        {
            CIImage *image = [[CIImage alloc] initWithContentsOfURL: fileUrl];
            fileUrl = nil;
            
            _thumbnail = [self createPhotoThumbnail: image];
            [self fetchThumbnailsFromOriginal: image];
        }
        [self sendPhotoToMugmover];
    }
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

// Note that the returned thumbnail is a Base64-encoded representation thereof
- (NSString *) createPhotoThumbnail: (CIImage *) image
{
    NSString *result = nil;

    if (image)
    {
        // scale the image
        Float64 scaleFactor = ((Float64) MAX_THUMB_DIM) / ((Float64)MAX(_processedWidth, _processedHeight));
        CGAffineTransform  scalingTransform = CGAffineTransformMakeScale(scaleFactor, scaleFactor);
        CIImage *scaledImage = [image imageByApplyingTransform: scalingTransform];

        NSMutableData* thumbJpegData = [[NSMutableData alloc] init];
        CGImageDestinationRef dest = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)thumbJpegData,
                                                                      (__bridge CFStringRef)@"public.jpeg",
                                                                      1,
                                                                      NULL);
        if (dest)
        {
            CGRect extent = [scaledImage extent];
            if (_processedHeight > _processedWidth)
            {
                extent.size.width = lroundl(scaleFactor * _processedWidth);
                extent.size.height = MAX_THUMB_DIM;
            }
            else
            {
                extent.size.width = MAX_THUMB_DIM;
                extent.size.height = lroundl(scaleFactor * _processedHeight);
            }

            CGImageRef img = [_library.ciContext createCGImage: scaledImage
                                                      fromRect: extent];
            CGImageDestinationAddImage(dest, img, nil);
            if (CGImageDestinationFinalize(dest))
            {
                result = [thumbJpegData base64EncodedStringWithOptions: 0];
            }
            else
            {
                DDLogError(@"Failed to generate photo thumbnail");
            }
            CGImageRelease(img);
            CFRelease(dest);
        }
        else
        {
            DDLogError(@"Failed to finalize photo thumbnail image");
        }
        thumbJpegData = nil;
    }
    return result;
}
- (NSMutableArray *) getCroppedRegions: (CIImage *) image
                       withCoordinates: (NSArray*) rectArray
                             thumbSize: (NSInteger) thumbSize
{
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity: [rectArray count]];
    
    if ((result) && (image))
    {
        for (NSArray *rect in rectArray)
        {
            CGRect cropRect = CGRectMake([[rect objectAtIndex: 0] doubleValue],
                                         [[rect objectAtIndex: 1] doubleValue],
                                         [[rect objectAtIndex: 2] doubleValue],
                                         [[rect objectAtIndex: 3] doubleValue]);
            
            CIImage *croppedImage = [image imageByCroppingToRect: cropRect];
            
            Float64 scaleFactor = thumbSize / [[rect objectAtIndex: 2] doubleValue];
            CGAffineTransform  scalingTransform = CGAffineTransformMakeScale(scaleFactor, scaleFactor);
            CIImage *scaledAndCroppedImage = [croppedImage imageByApplyingTransform: scalingTransform];
            
            NSMutableData* thumbJpegData = [[NSMutableData alloc] init];
            CGImageDestinationRef dest = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)thumbJpegData,
                                                                          (__bridge CFStringRef)@"public.jpeg",
                                                                          1,
                                                                          NULL);
            
            if (dest)
            {
                // Force the crop to be perfectly square. Due to rounding it's actually 101x102 or 101x101
                // or the like in most cases.
                CGRect extent = [scaledAndCroppedImage extent];
                extent.size.width = thumbSize;
                extent.size.height = thumbSize;
                CGImageRef img = [_library.ciContext createCGImage: scaledAndCroppedImage
                                                          fromRect: extent];
                
                CGImageDestinationAddImage(dest, img, nil);
                if (CGImageDestinationFinalize(dest))
                {
                    NSString *jpegAsString = [thumbJpegData base64EncodedStringWithOptions: 0];
                    [result addObject: @{@"jpeg": jpegAsString, @"scale": @(scaleFactor)}];
                }
                else
                {
                    DDLogError(@"Failed to generate face thumbnail");
                    DDLogError(@"        rect=%@ path=%@", rect, _iPhotoOriginalImagePath);
                    [result addObject: @{@"jpeg": @"", @"scale": @(scaleFactor)}];
                }
                CGImageRelease(img);
                CFRelease(dest);
            }
            else
            {
                DDLogError(@"Failed to finalize thumbnail image");
                [result addObject: @{}];
                
            }
        }
    }
    return result;
}

- (BOOL) fetchThumbnailsFromOriginal: (CIImage *) image
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
            idealDim = MIN(idealDim, physicalLimit);                             // The smallest wins

            Float64 left = [face.centerPoint x] - (idealDim / 2.0);
            Float64 bottom = (_processedHeight - [face.centerPoint y]) - (idealDim / 2.0);

            NSArray *rect = @[[NSNumber numberWithDouble: left],
                              [NSNumber numberWithDouble: bottom], // OSX uses the bottom-left corner for origin
                              [NSNumber numberWithDouble: idealDim],
                              [NSNumber numberWithDouble: idealDim]];
            [rectangles addObject: rect];
        }
        if (image)
        {
            NSMutableArray *thumbnails = [self getCroppedRegions: image
                                                 withCoordinates: rectangles
                                                       thumbSize: MAX_THUMB_DIM];
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
                    NSDictionary *thumb = thumbnails[counter];
                    face.thumbnail = [thumb valueForKey: @"jpeg"];
                    face.scaleFactor = [[thumb valueForKey: @"scale"] floatValue];
                    counter++;
                }
            }
        }
    }
    return YES;
}

- (void) sendPhotoToMugmover
{
    NSDictionary *cropProperties = @{
                                        @"cropOrigin":           [_cropOrigin asDictionary],
                                        @"croppedHeight":        [NSNumber numberWithLong: _croppedHeight],
                                        @"croppedWidth":         [NSNumber numberWithLong: _croppedWidth],
                                        @"rotationAngle":        [NSNumber numberWithDouble: _rotationAngle],
                                        @"straightenAngle":      [NSNumber numberWithDouble: _straightenAngle],
                                    };
    [_attributes setObject: _library.sourceDictionary forKey: @"source"];
    [_attributes setObject: cropProperties forKey: @"crop"];
    [_attributes setObject: _adjustmentsArray forKey: @"adjustments"];
    [[_attributes objectForKey: @"photo" ] setObject: _thumbnail forKey: @"thumbnail"];

    if (_faceArray)
    {
        NSMutableArray *facesProperties = [[NSMutableArray alloc] initWithCapacity: [_faceArray count]];
        for (MMFace *face in _faceArray)
        {
            [facesProperties addObject: [face properties]];

        }
        [_attributes setObject: facesProperties forKey: @"faces"];
    }

    // Now that we have everything, serialize the data to JSON and start the upload

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject: _attributes
                                                       options: 0
                                                         error: &error];
    if (!jsonData)
    {
        DDLogError(@"ERROR JSON Serialization returned: %@", error);
    }
    else
    {
        NSString *jsonString = [[NSString alloc] initWithData: jsonData encoding: NSUTF8StringEncoding];
        jsonData = nil;
        NSDictionary *postData = @{@"data": jsonString};
        _apiRequest = [[MMApiRequest alloc] initUploadForApiVersion: 1
                                                           bodyData: postData
                                                  completionHandler: ^(NSURLResponse *response, NSData *data, NSError *netError)
                                                                       {
                                                                           DDLogInfo(@"MM RESPONSE   status=%ld, hasData?=%d",
                                                                                   
                                                                                     (long)[(NSHTTPURLResponse *)response statusCode],
                                                                                     !!data);
                                                                           NSDictionary *results = [MMDataUtility parseJsonData: data];
                                                                           if (netError)
                                                                           {
                                                                               DDLogError(@"NETWORK ERROR error=%@", netError);
                                                                               if (results)
                                                                               {
                                                                                   DDLogInfo(@"             JSON Object %@", results);
                                                                               }
                                                                           }
                                                                       }
                                                ];
        postData = nil;
    }

}

- (void) releaseStrongPointers
{
    _adjustmentsArray = nil;
    _apiRequest = nil;
    [_attributes removeAllObjects];
    _attributes = nil;
    _cropOrigin = nil;
    [_exifDictionary removeAllObjects];
    _exifDictionary = nil;
    _faceArray = nil;
    [_flickrDictionary removeAllObjects];
    _flickrDictionary = nil;
    _iPhotoOriginalImagePath = nil;
    _masterUuid = nil;
    _oldNotesToDelete = nil;
    _originalDate = nil;
    _originalFilename = nil;
    _originalUrl = nil;
    _request = nil;
    _thumbnail = nil;
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
    // This kicks it off. It calls back through [MMPhoto setByteLength];
    [MMNetworkRequest getUrlByteLength: _originalUrl photo: self];
}

- (void) fetchFlickrSizes
{
    NSURLRequest *request = [_stream.flickrOauth apiRequest: @"flickr.photos.getSizes"
                                                 parameters: @{@"photo_id": [_flickrDictionary objectForKey: @"id"],
                                                               @"secret":  [_flickrDictionary objectForKey: @"secret"],
                                                               }
                                                       verb: @"GET"];
    ServiceResponseHandler processGetSizesResponse = ^(NSDictionary *responseDictionary)
    {
        NSArray *sizeArray = [responseDictionary valueForKeyPath: @"sizes.size"];
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
    };
    [_stream.flickrOauth processUrlRequest: request
                                     queue: _stream.streamQueue
                         remainingAttempts: MMDefaultRetries
                         completionHandler: processGetSizesResponse];

}

- (void) fetchFlickrInfo
{
    NSURLRequest *request = [_stream.flickrOauth apiRequest: @"flickr.photos.getInfo"
                                                 parameters: @{@"photo_id": [_flickrDictionary objectForKey: @"id"],
                                                               @"secret":  [_flickrDictionary objectForKey: @"secret"],
                                                               }
                                                       verb: @"GET"];
    ServiceResponseHandler processGetInfoResponse = ^(NSDictionary *responseDictionary)
    {
        NSString *originalSecret = [responseDictionary valueForKeyPath: @"photo.originalsecret"];
        NSString *originalFormat = [responseDictionary valueForKeyPath: @"photo.originalformat"];
        NSString *dateUploaded = [responseDictionary valueForKeyPath: @"photo.dateuploaded"];
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
        NSArray *noteArray = [responseDictionary valueForKeyPath: @"photo.notes.note"];
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
    };
    [_stream.flickrOauth processUrlRequest: request
                                     queue: _stream.streamQueue
                         remainingAttempts: MMDefaultRetries
                         completionHandler: processGetInfoResponse];

}

- (void) fetchFlickrExif
{
    NSURLRequest *request = [_stream.flickrOauth apiRequest: @"flickr.photos.getExif"
                                                 parameters: @{@"photo_id": [_flickrDictionary objectForKey: @"id"],
                                                               @"secret":  [_flickrDictionary objectForKey: @"secret"],
                                                              }
                                                       verb: @"GET"];
    ServiceResponseHandler processGetExifResponse = ^(NSDictionary *responseDictionary)
    {
        NSArray *exifArray = [responseDictionary valueForKeyPath: @"photo.exif"];
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
    };
    [_stream.flickrOauth processUrlRequest: request
                                     queue: _stream.streamQueue
                         remainingAttempts: MMDefaultRetries
                         completionHandler: processGetExifResponse];

}
/*
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
                           @"api_key": MUGMOVER_FLICKR_API_KEY_MACRO,
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
                          MUGMOVER_FLICKR_API_KEY_MACRO, @"api_key",
                          nil];
    [_flickrRequest callAPIMethodWithPOST: @"flickr.photos.notes.delete"
                               arguments: args];
}

    if ([pieces[0] isEqualToString: @"deleteNote"])
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
*/

@end