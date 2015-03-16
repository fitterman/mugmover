//
//  MMPhotoLibrary.m
//  Everything having to do with reading the local library.
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//

#import "MMPhotoLibrary.h"
#import "MMPhoto.h"
#import "MMFace.h"
#import "FMDB/FMDB.h"
#import "FMDB/FMResultSet.h"

@import QuartzCore.CIFilter;
@import QuartzCore.CoreImage.CIContext;
@import QuartzCore.CoreImage.CIFilter;

@implementation MMPhotoLibrary

#define PAGESIZE (50)
#define MAX_THUMB_DIM (100)

NSString *photosPath;

- (id) initWithPath: (NSString *) path
{
    self = [self init];
    if (self)
    {
        _colorspace = CGColorSpaceCreateDeviceRGB();
        _bitmapContext = CGBitmapContextCreate(NULL, MAX_THUMB_DIM, MAX_THUMB_DIM, 8, 0, _colorspace, (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
        _ciContext = [CIContext contextWithCGContext: _bitmapContext options: @{}];
    
        _libraryBasePath = path;
        NSString *facesPath = [path stringByAppendingPathComponent: @"Database/apdb/Faces.db"];
        NSString *photosPath = [path stringByAppendingPathComponent: @"Database/apdb/Library.apdb"];
        if ((!facesPath) || (!photosPath))
        {
            return nil;
        }

        _facesDatabase = [FMDatabase databaseWithPath: facesPath];
        _photosDatabase = [FMDatabase databaseWithPath: photosPath];

        DDLogInfo(@"Opening _photosPath=%@", photosPath);
        if (self.facesDatabase && self.photosDatabase &&
            [self.facesDatabase openWithFlags: SQLITE_OPEN_READONLY | SQLITE_OPEN_EXCLUSIVE] &&
            [self.photosDatabase openWithFlags: SQLITE_OPEN_READONLY | SQLITE_OPEN_EXCLUSIVE])
        {
            NSInteger versionMajor = [_photosDatabase
                                      intForQuery: @"SELECT propertyValue FROM RKAdminData "
                                                    "WHERE propertyArea = 'database' AND propertyName = 'versionMajor'"];
            NSInteger versionMinor = [_photosDatabase
                                      intForQuery: @"SELECT propertyValue FROM RKAdminData "
                                                    "WHERE propertyArea = 'database' AND propertyName = 'versionMinor'"];
            _databaseVersion = [NSString stringWithFormat: @"%ld.%ld", versionMajor, versionMinor];
            _databaseUuid = [_photosDatabase
                             stringForQuery: @"SELECT propertyValue FROM RKAdminData "
                                              "WHERE propertyArea = 'database' AND propertyName = 'databaseUuid'"];
            _databaseAppId = [_photosDatabase
                              stringForQuery: @"SELECT propertyValue FROM RKAdminData "
                                               "WHERE propertyArea = 'database' AND propertyName = 'applicationIdentifier'"];
            _sourceDictionary = @{
                                  @"app":             @"mugmover",
                                  @"appVersion":      (NSString *) [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"],
                                  @"databaseUuid":     _databaseUuid,
                                  @"databaseVersion":  _databaseVersion,
                                  @"databaseAppId":    _databaseAppId,
                                  };
            return self;
        }
        else
        {
            if (_facesDatabase)
            {
                DDLogError(@"facesDatabase at %@ failed to open with error %d (%@).", facesPath,
                      _facesDatabase.lastErrorCode, _facesDatabase.lastErrorMessage);
                [self close];
            }
            if (_photosDatabase)
            {
                DDLogError(@"photosDatabase at %@ failed to open with error %d (%@).", photosPath,
                      _photosDatabase.lastErrorCode, _photosDatabase.lastErrorMessage);
                [self close];
            }
            return nil;
        }
    }
    return self;
}

- (void) getPhotos
{
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat: @"yyyy-MM-dd HH:mm:ss"];
    dateFormat.timeZone = [NSTimeZone timeZoneWithName: @"UTC"];

    NSInteger recordCount  = [_photosDatabase
                              intForQuery: @"SELECT count(*) FROM RKMaster "
                                            "WHERE isInTrash != 1"];
    

    NSInteger counter = 0;
    NSInteger exifDiscrepancyCounter = 0;
    NSInteger exifPositiveCounter = 0;
    NSInteger exifNegativeCounter = 0;
    for (NSInteger offset = 0; offset < recordCount; offset += PAGESIZE)
    {
        NSString *query =  @"SELECT  m.uuid masterUuid, m.createDate,"
                            "        m.fileName, m.imagePath, m.originalVersionName, "
                            "        m.colorSpaceName, m.fileCreationDate, m.fileModificationDate, "
                            "        m.fileSize, m.imageDate, m.isMissing, m.originalFileName, "
                            "        m.originalFileSize, m.name, m.projectUuid, m.subtype, m.type, "
                            "        v.uuid versionUuid, v.versionNumber, "
                            "        v.fileName versionFilename, v.isOriginal, v.hasAdjustments, "
                            "        v.masterHeight, v.masterWidth, "
                            "        v.name versionName, v.processedHeight, v.processedWidth, v.rotation "
                            "FROM RKVersion v JOIN RKMaster m  ON v.masterUuid = m.uuid "
                            "WHERE v.isHidden != 1 AND v.showInLibrary = 1 "
        "AND m.uuid IN ('ypRSN43uT1Sr5nU4eW%%UA', 'BXJwbAn%R8Sk+T1p5KXncA') "
                            "ORDER BY m.createDate, m.uuid LIMIT ? OFFSET ? ";
        
        FMResultSet *resultSet = [_photosDatabase executeQuery: query
                                          withArgumentsInArray: @[@PAGESIZE, @(offset)]];
        while (resultSet && [resultSet next])
        {
            counter++;
            NSString *masterUuid = [resultSet stringForColumn: @"masterUuid"];
            Float64 createDate = [resultSet doubleForColumn: @"createDate"];
            NSDate *createDateTimestamp = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate: (NSTimeInterval) createDate];
            NSString *fileName = [resultSet stringForColumn: @"fileName"];
            NSString *imagePath = [resultSet stringForColumn: @"imagePath"];
            NSString *originalVersionName = [resultSet stringForColumn: @"originalVersionName"];

            NSString *colorSpaceName = [resultSet stringForColumn: @"colorSpaceName"];
            long long int fileCreationDate = [resultSet longLongIntForColumn: @"fileCreationDate"];
            NSDate *fileCreationDateTimestamp = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate: (NSTimeInterval) fileCreationDate];
            long long int fileModificationDate = [resultSet longLongIntForColumn: @"fileModificationDate"];
            NSDate *fileModificationDateTimestamp = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate: (NSTimeInterval) fileModificationDate];
            long long int fileSize = [resultSet longLongIntForColumn: @"fileSize"];
            long long int imageDate = [resultSet longLongIntForColumn: @"imageDate"];
            NSDate *imageDateTimestamp = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate: (NSTimeInterval) imageDate];
            long isMissing = [resultSet longForColumn: @"isMissing"];
            NSString *originalFileName = [resultSet stringForColumn: @"originalFileName"];
            long long int originalFileSize = [resultSet longLongIntForColumn: @"originalFileSize"];
            NSString *name = [resultSet stringForColumn: @"name"];
            NSString *projectUuid  = [resultSet stringForColumn: @"projectUuid"];
            NSString *subtype = [resultSet stringForColumn: @"subtype"];
            NSString *type = [resultSet stringForColumn: @"type"];

            NSString *versionUuid = [resultSet stringForColumn: @"versionUuid"];
            long versionNumber = [resultSet longForColumn: @"versionNumber"];
            
            NSString *versionFilename = [resultSet stringForColumn: @"versionFilename"];
            long isOriginal = [resultSet longForColumn: @"isOriginal"];
            long hasAdjustments = [resultSet longForColumn: @"hasAdjustments"];
            long masterHeight = [resultSet longForColumn: @"masterHeight"];
            long masterWidth = [resultSet longForColumn: @"masterWidth"];
            NSString *versionName = [resultSet stringForColumn: @"versionName"];
            long processedHeight = [resultSet longForColumn: @"processedHeight"];
            long processedWidth = [resultSet longForColumn: @"processedWidth"];
            long rotation = [resultSet longForColumn: @"rotation"];

            
            if (originalFileName == NULL)
            {
                originalFileName = @"";
            }
            
            NSDictionary *exif;
            if (hasAdjustments != 1)
            {
                exif = [self versionExifFromMasterPath: imagePath];
            }
            else
            {
                exif = [self versionExifFromMasterPath: imagePath
                                           versionUuid: versionUuid
                                       versionFilename: versionFilename
                                           versionName: versionName];

            }
            if (exif == NULL)
            {
                DDLogInfo(@">>> isOriginal=%ld", isOriginal);
                exif = @{};
                
            }
            
            NSDictionary *photoProperties =  @{
                                               // From the master
                                               @"masterUuid": masterUuid,
                                               @"createDateTimestamp": [dateFormat stringFromDate: createDateTimestamp],
                                               @"fileName": fileName,
                                               @"imagePath": [@[_libraryBasePath, imagePath] componentsJoinedByString: @"/"],
                                               @"originalVersionName": originalVersionName,
                                               // Not currently used, but of great interest
                                               @"colorSpaceName": (colorSpaceName ? colorSpaceName : @""),
                                               @"fileCreationDate": [dateFormat stringFromDate: fileCreationDateTimestamp],
                                               @"fileModificationDate": [dateFormat stringFromDate: fileModificationDateTimestamp],
                                               @"fileSize": @(fileSize),
                                               @"imageDate": [dateFormat stringFromDate: imageDateTimestamp],
                                               @"isMissing": @(isMissing),
                                               @"originalFilename": originalFileName,
                                               @"originalFileSize": @(originalFileSize),
                                               @"name": name,
                                               @"projectUuid": projectUuid,
                                               @"subtype": subtype,
                                               @"type": type,

                                               // From the version
                                               @"versionNumber": @(versionNumber),
                                               @"versionUuid": versionUuid,
                                               @"versionFilename":  versionFilename,
                                               @"isOriginal": @(isOriginal),
                                               @"masterHeight": @(masterHeight),
                                               @"masterWidth": @(masterWidth),
                                               @"processedHeight": @(processedHeight),
                                               @"processedWidth": @(processedWidth),
                                               @"rotation": @(rotation),
                                              };

            MMPhoto *photo = [[MMPhoto alloc] initFromPhotoProperties: photoProperties
                                                       exifProperties: exif
                                                              library: self];
            
            DDLogInfo(@"%5ld %@ %@ %ld %lu", counter, masterUuid, versionUuid, versionNumber, (unsigned long)[exif count]);
            DDLogInfo(@"      createDateTimestamp       %@", [dateFormat stringFromDate: createDateTimestamp]);
            DDLogInfo(@"      fileCreationDateTimestamp %@", [dateFormat stringFromDate: fileCreationDateTimestamp]);
            DDLogInfo(@"      imageDateTimestamp        %@", [dateFormat stringFromDate: imageDateTimestamp]);

            [photo processPhoto];

            
            /*
             After, compare photo.originalDate against imateDateTimestamp

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
            */
            
            //DDLogInfo(@"Master/Version   %@", jsonString);
                                   
            // DDLogInfo(@"MASTER     %ld %@ %@ %ld %@", counter, masterUuid, createDateTimestamp, versionNumber, versionUuid);
        }
    }
    DDLogInfo(@"MASTER     DONE");
    DDLogInfo(@"  Date/time mismatches detected=%ld (postive=%ld, negative=%ld)",
              exifDiscrepancyCounter, exifPositiveCounter, exifNegativeCounter);
    DDLogInfo(@"  counter=%ld", counter);
    DDLogInfo(@"TODO ImageIO: CreateMeThrew error #203 (Duplicate property or field node)");
    DDLogInfo(@"TODO Look into using imageTimezoneName for time conversions");
}

/*
    Masters have paths like "path to iphoto library/" + "Masters/" + "2012/05/14/20120514-132735/" + "03485_s_9aefb8sby3508.jpg"
    Versions are named like "path to iphoto library/" + "Previews/" + "2012/05/14/20120514-132735/" + versionUuid + "03485_s_9aefb8sby3508.jpg"

    The Master relative path is available from the imagePath column, e.g., '2012/03/20/20120320-075509/03485_s_9aefb8sby3508.jpg'
    The Version relative path must be constructed and as it is not apparent how the date part of the
    filename comes into being, the safest approach is to find the Master and Version, pull the imagePath
    split it into parts at the "/", drop the last element, and take the uuid of the Version object
    and the filename column as well.
*/
- (NSDictionary *) versionExifFromMasterUuid: (NSString *) masterUuid
{

    // This query gets the filename for the latest version of a single photo, based on the UUID
    // of the master image. By observation, all masters appear to have 2 versions, numbered 0 and 1,
    // so this could be reduced to merely looking for version 1 of the image, but it seems safer
    // to do it this way. NOTE: I have recently found two master with 3 versions, numbered 0, 1 and 2.
    NSArray *args = @[masterUuid];
    NSDictionary *result = nil;

    FMResultSet *versionRecord = [_photosDatabase executeQuery: @ "SELECT v.fileName versionFilename, v.name versionName, v.uuid versionUuid, imagePath "
                                                                  "FROM RKMaster m JOIN RKVersion v ON m.uuid = v.masterUuid "
                                                                  "INNER JOIN "
                                                                  "  (SELECT uuid, MAX(versionNumber) version FROM RKVersion x "
                                                                  "WHERE masterUuid = ? GROUP BY masterUuid) lastVersion "
                                                                  "ON v.uuid = lastVersion.uuid AND v.versionNumber = lastVersion.version "


                                          withArgumentsInArray: args];
    if (![versionRecord next])
    {
        return result;
    }

    NSString *versionName = [versionRecord stringForColumn: @"versionName"];
    NSString *versionFilename = [versionRecord stringForColumn: @"versionFilename"];
    NSString *versionUuid = [versionRecord stringForColumn: @"versionUuid"];
    NSString *masterPath = [versionRecord stringForColumn: @"imagePath"];

    return [self versionExifFromMasterPath: masterPath
                               versionUuid: versionUuid
                           versionFilename: versionFilename
                               versionName: versionName];
}

- (NSMutableDictionary *) versionExifFromMasterPath: (NSString *) masterPath
{
    NSArray *pathPieces = @[_libraryBasePath, @"Masters", masterPath];

    NSString *fullMasterPath = [pathPieces componentsJoinedByString: @"/"];
    if (fullMasterPath)
    {
        return [MMPhotoLibrary getImageExif: fullMasterPath];
    }
    return nil;
}

- (NSString *) versionPathFromMasterPath: (NSString *) masterPath
                             versionUuid: (NSString *) versionUuid
                         versionFilename: (NSString *) versionFilename
                             versionName: (NSString *) versionName
{
 
    /*
        This is a thorny problem. There are a few possibilities to look for.
        The versionUuid is used as part of the path, in which case we
        expect to find the versionName + ".jpg" as part of the filename.
     */
    NSArray *masterPathPieces = [masterPath componentsSeparatedByString: @"/"];
    if (masterPathPieces)
    {
        NSString *versionNamePlusJpg = [NSString stringWithFormat: @"%@.jpg", versionName];
        NSArray *pathPieces = @[_libraryBasePath,
                                @"Previews",
                                [masterPathPieces objectAtIndex: 0],
                                [masterPathPieces objectAtIndex: 1],
                                [masterPathPieces objectAtIndex: 2],
                                [masterPathPieces objectAtIndex: 3],
                                versionUuid,
                                versionNamePlusJpg];
        if (pathPieces)
        {
            NSString *versionPath = [pathPieces componentsJoinedByString: @"/"];
            // If that file exists, return the path
            if ([[NSFileManager defaultManager] fileExistsAtPath:versionPath])
            {
                return versionPath;
            }
            else
            {
                // The alternative is to go one level higher and use the given filename
                // which seems unlikely for a tiff, but I can't force that case.
                pathPieces = @[_libraryBasePath,
                               @"Previews",
                               [masterPathPieces objectAtIndex: 0],
                               [masterPathPieces objectAtIndex: 1],
                               [masterPathPieces objectAtIndex: 2],
                               [masterPathPieces objectAtIndex: 3],
                               versionFilename];
                versionPath = [pathPieces componentsJoinedByString: @"/"];
                if ([[NSFileManager defaultManager] fileExistsAtPath:versionPath])
                {
                    return versionPath;
                }
                else
                {
                    DDLogError(@"NO VERSION FOUND! KEEP SEARCHING FOR THE TRUTH.");
                    return NULL;
                }

            }
            
        }
    }
    return NULL;

}

- (NSMutableDictionary *) versionExifFromMasterPath: (NSString *) masterPath
                                        versionUuid: (NSString *) versionUuid
                                    versionFilename: (NSString *) versionFilename
                                        versionName: (NSString *) versionName
{
    NSString *versionPath = [self versionPathFromMasterPath: masterPath
                                                versionUuid: versionUuid
                                            versionFilename: versionFilename
                                                versionName: versionName];
    if (versionPath)
    {
        return [MMPhotoLibrary getImageExif: versionPath];
    }
    return nil;
}

// This method extracts Exif data from a local file
+(NSMutableDictionary*) getImageExif: (NSString*) filePath
{
    NSMutableDictionary* exifDictionary = nil;
    NSURL* fileURL = [NSURL fileURLWithPath : filePath];

    if (fileURL)
    {

        // load the bit image from the file url
        CGImageSourceRef source = CGImageSourceCreateWithURL ( (__bridge CFURLRef) fileURL, NULL);

        if (source)
        {

            // get image properties into a dictionary
            CFDictionaryRef metadataRef = CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);

            if (metadataRef)
            {

                // cast CFDictonaryRef to NSDictionary
                exifDictionary = [NSMutableDictionary dictionaryWithDictionary : (__bridge NSDictionary *) metadataRef];

                if (exifDictionary)
                {
                    NSError *error = NULL;
                    NSMutableDictionary *oldNew = [[NSMutableDictionary alloc] init];
                    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern: @"\\A\\{([^}]+)\\}\\Z"
                                                                                           options: 0
                                                                                             error: &error];
                    if (error)
                    {
                        DDLogError(@"Unable to create regex: error=%@", error);
                    }
                    for (NSString * key in [exifDictionary allKeys])
                    {
                        NSTextCheckingResult *match = [regex firstMatchInString: key
                                                                        options: 0
                                                                          range: NSMakeRange(0, [key length])];
                        {
                            if (match)
                            {
                                [oldNew setObject: [key substringWithRange: NSMakeRange(match.range.location + 1, match.range.length - 2)]
                                           forKey: key];
                            }
                        }
                    }
                    for (NSString *key in oldNew)
                    {
                        NSString *newKey = [oldNew objectForKey: key];
                        id objectToPreserve = [exifDictionary objectForKey: key];
                        [exifDictionary setObject:objectToPreserve forKey: newKey];
                        [exifDictionary removeObjectForKey: key];
                    }

                    [exifDictionary setValue: filePath forKey: @"_image"];
                    unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath: filePath error:nil] fileSize];
                    [exifDictionary setValue: @(fileSize) forKey: @"_fileSize"];
                }
            }

            CFRelease(source);
            source = nil;
        }
    }
    else
    {
        DDLogError(@"Error in reading local image file %@", filePath);
    }

    return exifDictionary;
}

- (void) close
{
    if (_facesDatabase)
    {
        [_facesDatabase close];
    }
    if (_photosDatabase)
    {
        [_photosDatabase close];
    }
    _databaseAppId = nil;
    _databaseUuid = nil;
    _databaseVersion = nil;
    _facesDatabase = nil;
    _photosDatabase = nil;
    _libraryBasePath = nil;
    CGContextRelease(_bitmapContext);
    CGColorSpaceRelease(_colorspace);
    _ciContext = nil;
    

}

@end
