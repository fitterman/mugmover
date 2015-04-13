//
// MMPhoto.m
// This class is the model for a photo as stored in iPhoto. It is closely allied with the MMFace
// class. Perhaps the relationship is too close. In any case, it instantiates and manipulates
// Photo objects. Note that the process begins with the extraction of a result dictionary from
// the database, whis handled by the MMPhotoLibrary class.
//
//  Created by Bob Fitterman on 11/27/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//

// TODO Review "SharingActivity.db" for matches

#import "FMDB/FMDatabase.h"
#import "FMDB/FMDatabaseAdditions.h"
#import "FMDB/FMResultSet.h"
#import "MMApiRequest.h"
#import "MMLibraryEvent.h"
#import "MMNetworkRequest.h"
#import "MMOauthFlickr.h"
#import "MMFace.h"
#import "MMPhoto.h"
#import "MMPhotolibrary.h"
#import "MMPoint.h"
#import "MMEnvironment.h"
#import "MMDataUtility.h"
#import "MMFileUtility.h"

@import QuartzCore.CIFilter;
@import QuartzCore.CoreImage.CIContext;
@import QuartzCore.CoreImage.CIFilter;

#define PAGESIZE (50)
#define MAX_THUMB_DIM (100)

NSInteger const MMDefaultRetries = 3;
#define BASE_QUERY  "SELECT  m.uuid masterUuid, m.createDate," \
                    "        m.fileName, m.imagePath, m.originalVersionName, " \
                    "        m.colorSpaceName, m.fileCreationDate, m.fileModificationDate, " \
                    "        m.fileSize, m.imageDate, m.isMissing, " \
                    "        m.originalFileName originalFilename, " /* Change the name */ \
                    "        m.originalFileSize, m.name, m.projectUuid, m.subtype, m.type, " \
                    "        v.uuid versionUuid, v.versionNumber, " \
                    "        v.fileName versionFilename, " \
                    "        v.isOriginal, v.hasAdjustments, " \
                    "        v.masterHeight, v.masterWidth, " \
                    "        v.name versionName, v.processedHeight, v.processedWidth, v.rotation " \
                    "FROM RKVersion v JOIN RKMaster m  ON v.masterUuid = m.uuid "
#define QUERY_BY_VERSION_UUID   BASE_QUERY \
                                "WHERE v.isHidden != 1 AND v.showInLibrary = 1 and v.uuid = ? "
#define QUERY_BY_EVENT_UUID     BASE_QUERY \
                                "WHERE v.isHidden != 1 AND v.showInLibrary = 1 and m.projectUuid = ? "


extern Float64 const MMDegreesPerRadian;

@implementation MMPhoto

+ (MMPhoto *) getPhotoByVersionUuid: (NSString *) versionUuid
                        fromLibrary: (MMPhotoLibrary *) library
{
    FMResultSet *resultSet = [library.photosDatabase executeQuery: @QUERY_BY_VERSION_UUID
                                             withArgumentsInArray: @[versionUuid]];
    if (resultSet && [resultSet next])
    {
        NSDictionary *resultDictionary = [resultSet resultDictionary];
        return [[MMPhoto alloc] initFromDictionary: resultDictionary
                                           library: library];
    }
    return nil;
}
+ (NSArray *) getPhotosFromLibrary: (MMPhotoLibrary *) library
                          forEvent: (MMLibraryEvent *) event
{
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat: @"yyyy-MM-dd HH:mm:ss"];
    dateFormat.timeZone = [NSTimeZone timeZoneWithName: @"UTC"];
    
    NSInteger recordCount  = [library.photosDatabase intForQuery: @"SELECT count(*) FROM RKMaster "
                                                                   "WHERE isInTrash != 1"];
    
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity: recordCount];

    NSInteger counter = 0;
    NSInteger exifDiscrepancyCounter = 0;
    NSInteger exifPositiveCounter = 0;
    NSInteger exifNegativeCounter = 0;
    
    NSString *eventUuid = [event uuid];

    NSString *sortOrder =  [library.photosDatabase
                            stringForQuery: @"SELECT sortKeyPath FROM RKAlbum WHERE uuid = 'eventFilterBarAlbum'"];
    NSString *orderClause = @"ORDER BY v.imageDate ";
    if ([sortOrder hasSuffix: @"&exifProperties.ImageDate"])
    {
        orderClause = @"ORDER BY v.imageDate ";
    }
    else if ([sortOrder hasSuffix: @"&iptcProperties.Keywords"])
    {
        // TODO this is unsupported because (a) it is complicated and (b) I don't believe many people use this.
        // NOTE: Aperture supports hierarchical keywords
    }
    else if ([sortOrder hasSuffix: @"&basicProperties.MainRating"])
    {
        orderClause = @"ORDER BY v.mainRating ";
    }
    else if ([sortOrder hasSuffix: @"&basicProperties.VersionName"])
    {
        orderClause = @"ORDER BY v.name ";
    }
    NSInteger sortAscending =  [library.photosDatabase
                                intForQuery: @"SELECT sortAscending FROM RKAlbum WHERE uuid = 'eventFilterBarAlbum'"];

    // This looks a little odd, but it's easier to just put in two tie-breakers without bothering
    // to see if one of the keys is redundant.
    if (!sortAscending)
    {
        orderClause = [orderClause stringByAppendingString: @" DESC, v.imageDate DESC, v.name DESC "];
    }
    else
    {
        orderClause = [orderClause stringByAppendingString: @", v.imageDate, v.name "];
    }

    NSString *query = [@QUERY_BY_EVENT_UUID stringByAppendingString: orderClause];
    FMResultSet *resultSet = [library.photosDatabase executeQuery: query
                                             withArgumentsInArray: @[eventUuid]];
    while (resultSet && [resultSet next])
    {
        counter++;
        Float64 createDate = [resultSet doubleForColumn: @"createDate"];
        NSDate *createDateTimestamp = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate: (NSTimeInterval) createDate];
        
        long long int fileCreationDate = [resultSet longLongIntForColumn: @"fileCreationDate"];
        NSDate *fileCreationDateTimestamp = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate: (NSTimeInterval) fileCreationDate];
        long long int fileModificationDate = [resultSet longLongIntForColumn: @"fileModificationDate"];
        NSDate *fileModificationDateTimestamp = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate: (NSTimeInterval) fileModificationDate];
        long long int imageDate = [resultSet longLongIntForColumn: @"imageDate"];
        NSDate *imageDateTimestamp = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate: (NSTimeInterval) imageDate];

        
        NSDictionary *resultDictionary = [resultSet resultDictionary];
        MMPhoto *photo = [[MMPhoto alloc] initFromDictionary: resultDictionary
                                                     library: library];
 /* ################################################################################################
  * TODO Restore this functionality
  
        NSDictionary *photoProperties =  @{
                                           // From the master
                                           @"createDateTimestamp": [dateFormat stringFromDate: createDateTimestamp],
                                           @"imagePath": [@[library.libraryBasePath, imagePath] componentsJoinedByString: @"/"],
                                           @"fileCreationDate": [dateFormat stringFromDate: fileCreationDateTimestamp],
                                           @"fileModificationDate": [dateFormat stringFromDate: fileModificationDateTimestamp],
                                           @"imageDate": [dateFormat stringFromDate: imageDateTimestamp],
                                           };
        DDLogInfo(@"      createDateTimestamp       %@", [dateFormat stringFromDate: createDateTimestamp]);
        DDLogInfo(@"      fileCreationDateTimestamp %@", [dateFormat stringFromDate: fileCreationDateTimestamp]);
        DDLogInfo(@"      imageDateTimestamp        %@", [dateFormat stringFromDate: imageDateTimestamp]);

    // After, compare photo.originalDate against imateDateTimestamp
  
        DDLogInfo(@"      Exif/DateTimeOriginal     %@", [dateFormat stringFromDate: exifDateTimestamp]);
        NSTimeInterval deltaTime = [exifDateTimestamp timeIntervalSinceDate: imageDateTimestamp];
  
        if (deltaTime != 0.0)
        {
            exifDiscrepancyCounter++;
            DDLogInfo(@"                                ^^^^^^^^^^^^^^^^^^^ %@", name);
            if (deltaTime > 0)
            {
                exifPositiveCounter++;
            }
            else
            {
                exifNegativeCounter++;
            }
        };

        //DDLogInfo(@"Master/Version   %@", jsonString);
        // DDLogInfo(@"MASTER     %ld %@ %@ %ld %@", counter, masterUuid, createDateTimestamp, versionNumber, versionUuid);
  */
        if (photo)
        {
            [result addObject: photo];
        }
        
    }
    // DDLogInfo(@"MASTER     DONE");
    // DDLogInfo(@"  Date/time mismatches detected=%ld (postive=%ld, negative=%ld)",
    //          exifDiscrepancyCounter, exifPositiveCounter, exifNegativeCounter);
    // DDLogInfo(@"  counter=%ld", counter);
    // DDLogInfo(@"TODO ImageIO: CreateMeThrew error #203 (Duplicate property or field node)");
    // DDLogInfo(@"TODO Look into using imageTimezoneName for time conversions");

    if (resultSet)
    {
        [resultSet close];
    }
    return result;
}

- (MMPhoto *) commonInitialization
{
    _rotationAngle = 0.0;
    _straightenAngle = 0.0;
    _cropOrigin = [[MMPoint alloc] initWithX: 0.0 y: 0.0];
    if (!_cropOrigin)
    {
        [self close];
        return nil;
    }
    _adjustmentsArray = [[NSMutableArray alloc] init];
    if (!_adjustmentsArray)
    {
        [self close];
        return nil;
    }
    return self;
}

/**
 * Constructs an MMPhoto object from a hash. Note that some elements, like the
 * exif data, are filled in later.
 */
- (MMPhoto *) initFromDictionary: (NSDictionary *) inDictionary
                         library: (MMPhotoLibrary *) library
{
    self = [self init];
    if (self)
    {
        if ([self commonInitialization] == nil)
        {
            [self close];
            return nil;
        }
    }
    _library = library;
    _verboseLogging = _library.verboseLogging;
    
    _masterUuid = [inDictionary valueForKey: @"masterUuid"];
    _masterHeight = [[inDictionary valueForKey: @"masterHeight"] doubleValue];
    _masterWidth = [[inDictionary valueForKey: @"masterWidth"] doubleValue];
    _processedHeight = [[inDictionary valueForKey: @"processedHeight"] doubleValue];
    _processedWidth = [[inDictionary valueForKey: @"processedWidth"] doubleValue];
    _rotationAngle = [[inDictionary valueForKey: @"rotation"] doubleValue];
    _versionUuid = [inDictionary valueForKey: @"versionUuid"];
    _version = [[inDictionary valueForKey: @"versionNumber"] longValue];
    _attributes = [[NSMutableDictionary alloc] initWithCapacity: 20];
    [_attributes setObject: [_library sourceDictionary] forKey: @"source"];
    [_attributes setObject: [inDictionary mutableCopy] forKey: @"photo"];
    return self;
}

- (BOOL) populateExifFromSourceFile
{
    BOOL result = YES;
    NSMutableDictionary *exifProperties;
    NSString *imagePath = [_attributes valueForKeyPath: @"photo.imagePath"];
    NSInteger hasAdjustments = [[_attributes valueForKeyPath: @"photo.hasAdjustments"] integerValue];
    NSString *versionUuid = nil;
    NSString *versionFilename = nil;
    NSString *versionName = nil;
    if ((hasAdjustments == 1) || (_rotationAngle != 0.0))
    {
        versionUuid = [_attributes valueForKeyPath: @"photo.versionUuid"];
        versionFilename = [_attributes valueForKeyPath: @"photo.versionFilename"];
        versionName = [_attributes valueForKeyPath: @"photo.versionName"];
    }
    _iPhotoOriginalImagePath = [_library versionPathFromMasterPath: imagePath
                                                       versionUuid: versionUuid
                                                   versionFilename: versionFilename
                                                       versionName: versionName];
    if (_iPhotoOriginalImagePath)
    {
        exifProperties = [MMFileUtility exifForFileAtPath: _iPhotoOriginalImagePath];
    }

    if (!exifProperties)
    {
        DDLogInfo(@">>> isOriginal=%ld", [[_attributes valueForKeyPath: @"photo.isOriginal"] integerValue]);
        exifProperties = [[NSMutableDictionary alloc] init];
        result = NO;
    }

    [self populateDateFromExif: exifProperties];
    [_attributes setObject: exifProperties forKey: @"exif"];
    return result;
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
    // TODO Use the same logic here as in the MMLibraryEvent for determining zone.
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

#pragma mark Rotation and cropping code
- (void) processPhoto
{
    @autoreleasepool {
        [self populateExifFromSourceFile];
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
    }
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

- (void) attachServiceDictionary: (NSDictionary *) serviceDictionary
{
    [_attributes setObject: serviceDictionary forKey: @"service"];
}

- (BOOL) sendPhotoToMugmover
{
    NSLog(@"--");
    NSDictionary *cropProperties = @{
                                        @"cropOrigin":           [_cropOrigin asDictionary],
                                        @"croppedHeight":        [NSNumber numberWithLong: _croppedHeight],
                                        @"croppedWidth":         [NSNumber numberWithLong: _croppedWidth],
                                        @"rotationAngle":        [NSNumber numberWithDouble: _rotationAngle],
                                        @"straightenAngle":      [NSNumber numberWithDouble: _straightenAngle],
                                    };
    [_attributes setObject: cropProperties forKey: @"crop"];
    if (_library.sourceDictionary)
    {
        [_attributes setObject: _library.sourceDictionary forKey: @"source"];
    }
    if (_adjustmentsArray)
    {
        [_attributes setObject: _adjustmentsArray forKey: @"adjustments"];
    }
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
        return NO;
    }

    NSString *jsonString = [[NSString alloc] initWithData: jsonData encoding: NSUTF8StringEncoding];
    jsonData = nil;
    NSDictionary *postData = @{@"data": jsonString};
    ServiceResponseHandler uploadResponseHandler = ^(NSDictionary *responseData)
    {
        DDLogInfo(@"responseData = %@", responseData);
    };
    BOOL response = [MMApiRequest synchronousUpload: postData // values should NOT be URLEncoded
                                  completionHandler: uploadResponseHandler];
    return response;
}

- (void) close
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
}

#pragma mark Utility methods
- (Float64) aspectRatio
{
    return _processedWidth / _processedHeight;
}


#pragma mark Attribute Accessors
- (NSString *) title
{
    NSString *title = [self.flickrDictionary  objectForKey: @"title"];
    if (![title length])
    {
        title = @"No title";
    }
    return title;
}

- (NSString *) fileName
{
    return [_attributes valueForKeyPath: @"photo.fileName"];
}

- (NSNumber *) fileSize
{
    return [_attributes valueForKeyPath: @"photo.fileSize"];
}

- (NSString *) fullImagePath
{
    return [_library versionPathFromMasterPath: [_attributes valueForKeyPath: @"photo.imagePath"]
                                   versionUuid: [_attributes valueForKeyPath: @"photo.versionUuid"]
                               versionFilename: [_attributes valueForKeyPath: @"photo.versionFilename"]
                                   versionName: [_attributes valueForKeyPath: @"photo.versionName"]];
}

- (NSString *) originalImagePath
{
    if (!_exifDictionary)
    {
        [self populateExifFromSourceFile];
    }
    return self.iPhotoOriginalImagePath;
}

- (NSString *) versionName
{
    return [_attributes valueForKeyPath: @"photo.versionName"];
}


@end