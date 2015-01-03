//
//  MMPhotoLibrary.m
//  mugmover
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//

#import "MMPhotoLibrary.h"
#import "MMFace.h"
#import "FMDB/FMDB.h"
#import "FMDB/FMResultSet.h"

@implementation MMPhotoLibrary

NSString *facesPath;
NSString *photosPath;

- (id)initWithPath:(NSString *)value
{
    self = [self init];
    if (self)
    {
        facesPath = [NSString stringWithFormat:@"%@/%@", value, @"Faces.db"];
        self.facesDatabase = [FMDatabase databaseWithPath:facesPath];
        photosPath = [NSString stringWithFormat:@"%@/%@", value, @"Library.apdb"];
        self.photosDatabase = [FMDatabase databaseWithPath:photosPath];
        
        if (self.facesDatabase && self.photosDatabase &&
            [self.facesDatabase open] && [self.photosDatabase open])
        {
            return self;
        }
        else
        {
            if (!self.facesDatabase)
            {
                // NSLog(@"ERROR facesDatabase at %@ failed to open.", facesPath);
            }
            else
            {
                [self.facesDatabase close];
            }
            if (!self.photosDatabase)
            {
                // NSLog(@"ERROR photosDatabase at %@ failed to open.", photosPath);
            }
            else
            {
                [self.photosDatabase close];
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
    NSArray *args = [NSArray arrayWithObjects: masterUuid, nil];
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
    
    return [MMPhotoLibrary versionExifFromMasterPath: masterPath
                                         versionUuid: versionUuid
                                     versionFilename: versionFilename];
}

+ (NSDictionary *) versionExifFromMasterPath: (NSString *) masterPath
                                 versionUuid: (NSString *) versionUuid
                             versionFilename: (NSString *) versionFilename
{
    NSArray *masterPathPieces = [masterPath componentsSeparatedByString: @"/"];
    NSArray *pathPieces = [NSArray arrayWithObjects: @"/Users/Bob/Pictures/Jay Phillips",
                                                     @"Previews",
                                                     [masterPathPieces objectAtIndex: 0],
                                                     [masterPathPieces objectAtIndex: 1],
                                                     [masterPathPieces objectAtIndex: 2],
                                                     [masterPathPieces objectAtIndex: 3],
                                                     versionUuid,
                                                     versionFilename,
                                                     nil];
    
    NSString *versionPath = [pathPieces componentsJoinedByString: @"/"];
    if (versionPath)
    {
        return [MMPhotoLibrary getImageEXIF: versionPath];
    }
    return nil;
}

// This method extracts Exif data from a local file, which we probably do not need to do!
+(NSDictionary*) getImageEXIF:(NSString*) filePath
{
    NSDictionary* exifDictionary = nil;
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
                exifDictionary = [NSDictionary dictionaryWithDictionary : (__bridge NSDictionary *)metadataRef];
                if (exifDictionary)
                {
                    NSDictionary *iptcDictionary = [exifDictionary objectForKey: @"{IPTC}"];
                    if (iptcDictionary)
                    {
                        NSString *digitalCreationDate = [iptcDictionary objectForKey: @"DigitalCreationDate"];
                        NSString *digitalCreationTime = [iptcDictionary objectForKey: @"DigitalCreationTime"];
                        NSLog(@"IPTC TIMESTAMP  %@ %@", digitalCreationDate, digitalCreationTime);
                    }
                }
            }
            
            CFRelease(source);
            source = nil;
        }
    }
    else
    {
        NSLog ( @"Error in reading file");
    }
    
    return exifDictionary;
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
 
 // Returns an array of matching records
 func masterVersions(masterUuid:String) -> FMResultSet
 {
 
 let versionSet = db.executeQuery("SELECT * FROM Versions WHERE masterUuid = ? ORDER BY versionNumber DESC",
 withArgumentsInArray: [masterUuid])
 return versionSet;
 }
 }
*/