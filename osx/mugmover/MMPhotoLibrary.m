//
//  MMPhotoLibrary.m
//  Everything having to do with reading the local library.
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//

#import "MMFileUtility.h"
#import "MMLibraryEvent.h"
#import "MMPhotoLibrary.h"
#import "MMPhoto.h"
#import "MMFace.h"
#import "FMDB/FMDB.h"
#import "FMDB/FMResultSet.h"

@import QuartzCore.CIFilter;
@import QuartzCore.CoreImage.CIContext;
@import QuartzCore.CoreImage.CIFilter;

@implementation MMPhotoLibrary

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
    
        NSDateFormatter *exifDateFormat1 = [[NSDateFormatter alloc] init];
        [exifDateFormat1 setDateFormat: @"yyyy:MM:dd HH:mm:ss"];
        exifDateFormat1.timeZone = [NSTimeZone timeZoneWithName: @"UTC"];
        
        NSDateFormatter *exifDateFormat2 = [[NSDateFormatter alloc] init];
        [exifDateFormat2 setDateFormat: @"MMM d, yyyy, hh:mm:ss a"];
        exifDateFormat2.timeZone = [NSTimeZone timeZoneWithName: @"UTC"];
        
        _exifDateFormatters = @[exifDateFormat1, exifDateFormat2];

        _libraryBasePath = path;
        NSString *facesPath = [path stringByAppendingPathComponent: @"Database/apdb/Faces.db"];
        NSString *photosPath = [path stringByAppendingPathComponent: @"Database/apdb/Library.apdb"];
        NSString *propertiesPath = [path stringByAppendingPathComponent: @"Database/apdb/Properties.apdb"];
        if ((!facesPath) || (!photosPath) || (!propertiesPath))
        {
            return nil;
        }

        _facesDatabase = [FMDatabase databaseWithPath: facesPath];
        _photosDatabase = [FMDatabase databaseWithPath: photosPath];
        _propertiesDatabase = [FMDatabase databaseWithPath: propertiesPath];

        DDLogInfo(@"Opening _photosPath=%@", photosPath);
        if (_facesDatabase && _photosDatabase && _propertiesDatabase &&
            [_facesDatabase openWithFlags: SQLITE_OPEN_READONLY | SQLITE_OPEN_EXCLUSIVE] &&
            [_photosDatabase openWithFlags: SQLITE_OPEN_READONLY | SQLITE_OPEN_EXCLUSIVE] &&
            [_propertiesDatabase openWithFlags: SQLITE_OPEN_READONLY | SQLITE_OPEN_EXCLUSIVE])
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
            if (_propertiesDatabase)
            {
                DDLogError(@"propertiesDatabase at %@ failed to open with error %d (%@).", photosPath,
                           _propertiesDatabase.lastErrorCode, _propertiesDatabase.lastErrorMessage);
                [self close];
            }
            return nil;
        }
    }
    return self;
}

/*
    Masters have paths like "path to iphoto library/" + "Masters/" + "2012/05/14/20120514-132735/" + "03485_s_9aefb8sby3508.jpg"
    Versions are named like "path to iphoto library/" + "Previews/" + "2012/05/14/20120514-132735/" + versionUuid + "03485_s_9aefb8sby3508.jpg"

    The Master relative path is available from the imagePath column, e.g., '2012/03/20/20120320-075509/03485_s_9aefb8sby3508.jpg'
    The Version relative path must be constructed and as it is not apparent how the date part of the
    file name comes into being, the safest approach is to find the Master and Version, pull the imagePath
    split it into parts at the "/", drop the last element, and take the uuid of the Version object
    and the fileName column as well.
*/
- (NSDictionary *) versionExifFromMasterUuid: (NSString *) masterUuid
{

    // This query gets the file name for the latest version of a single photo, based on the UUID
    // of the master image. By observation, all masters appear to have 2 versions, numbered 0 and 1,
    // so this could be reduced to merely looking for version 1 of the image, but it seems safer
    // to do it this way. NOTE: I have recently found two master with 3 versions, numbered 0, 1 and 2.
    NSArray *args = @[masterUuid];
    NSDictionary *result = nil;

    FMResultSet *versionRecord = [_photosDatabase executeQuery: @ "SELECT v.fileName versionFileName, v.name versionName, v.uuid versionUuid, imagePath "
                                                                  "FROM RKMaster m JOIN RKVersion v ON m.uuid = v.masterUuid "
                                                                  "INNER JOIN "
                                                                  "  (SELECT uuid, MAX(versionNumber) version FROM RKVersion x "
                                                                  "WHERE masterUuid = ? GROUP BY masterUuid) lastVersion "
                                                                  "ON v.uuid = lastVersion.uuid AND v.versionNumber = lastVersion.version "


                                          withArgumentsInArray: args];
    if (![versionRecord next])
    {
        [versionRecord close];
        return result;
    }

    NSString *versionName = [versionRecord stringForColumn: @"versionName"];
    NSString *versionFileName = [versionRecord stringForColumn: @"versionFileName"];
    NSString *versionUuid = [versionRecord stringForColumn: @"versionUuid"];
    NSString *masterPath = [versionRecord stringForColumn: @"imagePath"];
    [versionRecord close];

    return [self versionExifFromMasterPath: masterPath
                               versionUuid: versionUuid
                           versionFileName: versionFileName
                               versionName: versionName];
}

- (NSString *) versionPathFromMasterPath: (NSString *) partialMasterPath
                             versionUuid: (NSString *) versionUuid
                         versionFileName: (NSString *) versionFileName
                             versionName: (NSString *) versionName
{
 
    // If there's no uuid, then just return the master path. It should never
    // happen, but life doesn't work that way.
    
    if (!versionUuid)
    {
        return [@[_libraryBasePath,
                  @"Masters",
                  partialMasterPath] componentsJoinedByString: @"/"];
    }
    /*
        This is a thorny problem. There are a few possibilities to look for.
        The versionUuid is used as part of the path, in which case we
        expect to find the versionName + ".jpg" as part of the file name.
     */
    NSArray *masterPathPieces = [partialMasterPath componentsSeparatedByString: @"/"];
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
                // The alternative is to go one level higher and use the given file name
                // which seems unlikely for a tiff, but I can't force that case.
                pathPieces = @[_libraryBasePath,
                               @"Previews",
                               [masterPathPieces objectAtIndex: 0],
                               [masterPathPieces objectAtIndex: 1],
                               [masterPathPieces objectAtIndex: 2],
                               [masterPathPieces objectAtIndex: 3],
                               versionFileName];
                versionPath = [pathPieces componentsJoinedByString: @"/"];
                if ([[NSFileManager defaultManager] fileExistsAtPath:versionPath])
                {
                    return versionPath;
                }
                else
                {
                    // Yet another case, apparently...
                    return [@[_libraryBasePath,
                              @"Masters",
                              partialMasterPath] componentsJoinedByString: @"/"];

                }

            }
            
        }
    }
    return NULL;

}

- (NSMutableDictionary *) versionExifFromMasterPath: (NSString *) masterPath
{
    return [self versionExifFromMasterPath: masterPath
                               versionUuid: nil
                           versionFileName: nil
                               versionName: nil];
}

- (NSMutableDictionary *) versionExifFromMasterPath: (NSString *) masterPath
                                        versionUuid: (NSString *) versionUuid
                                    versionFileName: (NSString *) versionFileName
                                        versionName: (NSString *) versionName
{
    NSString *versionPath = [self versionPathFromMasterPath: masterPath
                                                versionUuid: versionUuid
                                            versionFileName: versionFileName
                                                versionName: versionName];
    if (versionPath)
    {
        return [MMFileUtility exifForFileAtPath: versionPath];
    }
    return nil;
}

- (void) close
{
    if (_facesDatabase)
    {
        [_facesDatabase close];
        _facesDatabase = nil;
    }
    if (_photosDatabase)
    {
        [_photosDatabase close];
        _photosDatabase = nil;
    }
    if (_propertiesDatabase)
    {
        [_propertiesDatabase close];
        _propertiesDatabase = nil;
    }
    _databaseAppId = nil;
    _databaseUuid = nil;
    _databaseVersion = nil;
    _libraryBasePath = nil;
    CGContextRelease(_bitmapContext);
    CGColorSpaceRelease(_colorspace);
    _ciContext = nil;
    _exifDateFormatters = nil;
}

- (NSString *) baseName
{
    return [[NSURL fileURLWithPath: _libraryBasePath] lastPathComponent];
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"Photos via Mugmover from %@", [self baseName]];
}

- (NSString *) displayName
{
    return [NSString stringWithFormat: @"%@ via Mugmover", [self baseName]];
}


@end
