//
//  MMPhotoLibrary.m
//  Everything having to do with reading the local library.
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//

#import "MMPhotoLibrary.h"
#import "MMFace.h"
#import "FMDB/FMDB.h"
#import "FMDB/FMResultSet.h"

@import QuartzCore.CIFilter;
@import QuartzCore.CoreImage.CIContext;
@import QuartzCore.CoreImage.CIFilter;

@implementation MMPhotoLibrary


NSString *photosPath;

- (id) initWithPath: (NSString *) path
{
    self = [self init];
    if (self)
    {
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
    // to do it this way.
    NSArray *args = @[masterUuid];
    NSDictionary *result = nil;
    
    FMResultSet *versionRecord = [_photosDatabase executeQuery: @ "SELECT v.filename, v.uuid versionUuid, imagePath "
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
    
    NSString *versionFilename = [versionRecord stringForColumn: @"filename"];
    NSString *versionUuid = [versionRecord stringForColumn: @"versionUuid"];
    NSString *masterPath = [versionRecord stringForColumn: @"imagePath"];
    
    return [self versionExifFromMasterPath: masterPath
                               versionUuid: versionUuid
                           versionFilename: versionFilename];
}

- (NSMutableDictionary *) versionExifFromMasterPath: (NSString *) masterPath
{
    NSArray *pathPieces = @[_libraryBasePath, @"Masters", masterPath];
    
    NSString *fullMasterPath = [pathPieces componentsJoinedByString: @"/"];
    if (fullMasterPath)
    {
        DDLogInfo(@"           fullMasterPath=%@", fullMasterPath);
        return [MMPhotoLibrary getImageExif: fullMasterPath];
    }
    return nil;
}

- (NSString *) versionPathFromMasterPath: (NSString *) masterPath
                             versionUuid: (NSString *) versionUuid
                         versionFilename: (NSString *) versionFilename
{
    NSArray *masterPathPieces = [masterPath componentsSeparatedByString: @"/"];
    if (masterPathPieces != NULL)
    {
        NSArray *pathPieces = @[_libraryBasePath,
                                @"Previews",
                                [masterPathPieces objectAtIndex: 0],
                                [masterPathPieces objectAtIndex: 1],
                                [masterPathPieces objectAtIndex: 2],
                                [masterPathPieces objectAtIndex: 3],
                                versionUuid,
                                versionFilename];
        if (pathPieces != NULL)
        {
            NSString *versionPath = [pathPieces componentsJoinedByString: @"/"];
            return versionPath;
        }
    }
    return NULL;
    
}

- (NSMutableDictionary *) versionExifFromMasterPath: (NSString *) masterPath
                                 versionUuid: (NSString *) versionUuid
                             versionFilename: (NSString *) versionFilename
{
    NSString *versionPath = [self versionPathFromMasterPath: masterPath
                                                versionUuid: versionUuid
                                            versionFilename: versionFilename];
    if (versionPath)
    {
        DDLogInfo(@"VERSION EXIF  versionPath=%@", versionPath);
        return [MMPhotoLibrary getImageExif: versionPath];
    }
    return nil;
}


// Version 2
+ (NSMutableArray *) getCroppedRegions: (NSString*) filePath
                       withCoordinates: (NSArray*) rectArray
                             thumbSize: (NSInteger) thumbSize
{
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity: [rectArray count]];
    NSURL* fileURL = [NSURL fileURLWithPath : filePath];
    
    // After the crop, then scale, the resulting image was not always an integer size and in fact
    // was not even square in some cases. To rectify this, we recrop one more time at the end with
    // definitive metrics

    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmapContext = CGBitmapContextCreate(NULL, thumbSize, thumbSize, 8, 0, colorspace, (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
    CIContext *context = [CIContext contextWithCGContext: bitmapContext options: @{}];
    // TODO Is there a release for the CIContext?
    
    if ((result != NULL) && (fileURL != NULL))
    {
        CIImage *image = [[CIImage alloc] initWithContentsOfURL: fileURL];

        if (image != NULL)
        {
            for (NSArray *rect in rectArray)
            {
                CGRect cropRect = CGRectMake([[rect objectAtIndex: 0] doubleValue],
                                             [[rect objectAtIndex: 1] doubleValue],
                                             [[rect objectAtIndex: 2] doubleValue],
                                             [[rect objectAtIndex: 3] doubleValue]);

                CIImage *croppedImage = [image imageByCroppingToRect: cropRect];

                // scale the image
                CIFilter *scaleFilter = [CIFilter filterWithName: @"CILanczosScaleTransform"];
                [scaleFilter setValue: croppedImage forKey: @"inputImage"];
                NSNumber *scaleFactor = [[NSNumber alloc] initWithFloat:(float) thumbSize / [[rect objectAtIndex: 2] doubleValue]];
                [scaleFilter setValue: scaleFactor forKey: @"inputScale"];
                [scaleFilter setValue: @1.0 forKey: @"inputAspectRatio"];
                CIImage *scaledAndCroppedImage = [scaleFilter valueForKey: @"outputImage"];

                NSMutableData* thumbJpegData = [[NSMutableData alloc] init];
                CGImageDestinationRef dest = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)thumbJpegData,
                                                                              (__bridge CFStringRef)@"public.jpeg",
                                                                              1,
                                                                              NULL);
                //CFURLRef saveUrl2 = (__bridge CFURLRef)[NSURL fileURLWithPath:[@"~/Desktop/lockwood-crop-2.jpg" stringByExpandingTildeInPath]];
                //CGImageDestinationRef dest = CGImageDestinationCreateWithURL(saveUrl2, kUTTypeJPEG, 1, NULL);
                if (dest != NULL)
                {
                    CGImageRef img = [context createCGImage:scaledAndCroppedImage
                                                   fromRect:[scaledAndCroppedImage extent]];
                    CGImageDestinationAddImage(dest, img, nil);
                    if (CGImageDestinationFinalize(dest))
                    {
                        NSString *jpegAsString = [thumbJpegData base64EncodedStringWithOptions: 0];
                        [result addObject: @{@"jpeg": jpegAsString, @"scale": scaleFactor}];
                    }
                    else
                    {
                        DDLogError(@"Failed to generate face thumbnail");
                        [result addObject: @{}];
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
    }
    CGContextRelease(bitmapContext);
    CGColorSpaceRelease(colorspace);
    return result;
}

// The method takes in an image and resizes it to some specified size
+ (CGImageRef)resizeCGImage: (CGImageRef)image
                    toWidth: (NSInteger)width
                   toHeight: (NSInteger)height
{
    // create context, keeping original image properties
    CGColorSpaceRef colorspace = CGImageGetColorSpace(image);
    CGContextRef context = CGBitmapContextCreate(NULL,
                                                 width,
                                                 height,
                                                 CGImageGetBitsPerComponent(image),
                                                 CGImageGetBytesPerRow(image),
                                                 colorspace,
                                                 (CGBitmapInfo)CGImageGetAlphaInfo(image));
    CGColorSpaceRelease(colorspace);

    if (context == NULL)
        return nil;
    
    // draw image to context (resizing it)
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    
    // extract resulting image from context
    CGImageRef imgRef = CGBitmapContextCreateImage(context);
    CGContextRelease(context);

    return imgRef;
}


// This method extracts Exif data from a local file, which we probably do not need to do!
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
                    [exifDictionary setValue: filePath forKey: @"_image"];
                    NSDictionary *iptcDictionary = [exifDictionary objectForKey: @"{IPTC}"];
                    if (iptcDictionary)
                    {
                        NSString *digitalCreationDate = [iptcDictionary objectForKey: @"DigitalCreationDate"];
                        NSString *digitalCreationTime = [iptcDictionary objectForKey: @"DigitalCreationTime"];
                        DDLogInfo(@"IPTC TIMESTAMP  %@ %@", digitalCreationDate, digitalCreationTime);
                    }
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
}

@end
/*
 import Foundation
 
 
 // Returns a FMResultSet and the position is on the first record (the master photo)
 // unless it does not exist, in which this method returns nil
 func masterPhoto(uuid:String) -> FMResultSet?
 {
 //  For reference, this is the schema of the RKMaster record
 //
 //  modelId integer primary key, uuid varchar, name varchar, projectUuid varchar,
 //  importGroupUuid varchar, fileVolumeUuid varchar, alternateMasterUuid varchar,
 //  originalVersionUuid varchar, originalVersionName varchar, fileName varchar,
 //  type varchar, subtype varchar, fileIsReference integer, isExternallyEditable integer,
 //  isTrulyRaw integer, isMissing integer, hasAttachments integer, hasNotes integer,
 //  hasFocusPoints integer, imagePath varchar, fileSize integer, pixelFormat integer,
 //  duration decimal, imageDate timestamp, fileCreationDate timestamp,
 //  fileModificationDate timestamp, imageHash varchar, originalFileName varchar,
 //  originalFileSize integer, imageFormat integer, createDate timestamp,
 //  isInTrash integer, faceDetectionState integer, colorSpaceName varchar,
 //  colorSpaceDefinition blob, fileAliasData blob, importedBy integer,
 //  streamAssetId varchar, streamSourceUuid varchar, burstUuid varchar
 
 
 let masterSet = db.executeQuery("SELECT * FROM RKMaster WHERE uuid = ?", withArgumentsInArray: [uuid])
 if !masterSet.next()
 {
 // Indicates no record matched
 return nil
 }
 return masterSet
 }
 
 // For reference, this is the schema of the RKVersion table
 //
 //  modelId integer primary key, uuid varchar, name varchar, fileName varchar,
 //  versionNumber integer, stackUuid varchar, masterUuid varchar, masterId integer,
 //  rawMasterUuid varchar, nonRawMasterUuid varchar, projectUuid varchar,
 //  imageTimeZoneName varchar, imageDate timestamp, mainRating integer,
 //  isHidden integer, isFlagged integer, isOriginal integer, isEditable integer,
 //  colorLabelIndex integer, masterHeight integer, masterWidth integer,
 //  processedHeight integer, processedWidth integer, rotation integer,
 //  hasAdjustments integer, hasEnabledAdjustments integer, hasNotes integer,
 //  createDate timestamp, exportImageChangeDate timestamp,
 //  exportMetadataChangeDate timestamp, isInTrash integer, thumbnailGroup varchar,
 //  overridePlaceId integer, exifLatitude decimal, exifLongitude decimal,
 //  renderVersion integer, adjSeqNum integer, supportedStatus integer,
 //  videoInPoint varchar, videoOutPoint varchar, videoPosterFramePoint varchar,
 //  showInLibrary integer, editState integer, contentVersion integer,
 //  propertiesVersion integer, rawVersion varchar,
 //  faceDetectionIsFromPreview integer, faceDetectionRotationFromMaster integer,
 //  editListData blob, hasKeywords integer
 //
 //  NOTE: isInTrash tracks the value in the master record (it's denormalized)
 //  NOTE: For one database, the nonRawMasterUuid was filled in and the rawMasterUuid was consistently null
 //
 //  Fields of interest
 //  String: name, fileName, masterUuid, rawMasterUuid, nonRawMasterUuid,
 //  Bool: isHidden, isOriginal, hasAdjustments, hasEnabledAdjustments, hasNotes,
 //          faceDetectionIsFromPreview, hasKeywords,
 //  Integer: faceDetectionRotationFromMaster, masterHeight, masterWidth,
 //          processedHeight, processedWidth, rotation,
 

*/