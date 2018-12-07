//
//  MMPhotoLibrary.h
//  mugmover
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FMDatabase;
@class MMLibraryEvent;

@interface MMPhotoLibrary : NSObject

@property (strong, readonly)    NSString *          databaseAppId;
@property (strong, readonly)    NSString *          databaseUuid;
@property (strong, readonly)    NSString *          databaseVersion;
@property (strong, readonly)    NSMutableArray *    events;
@property (strong, readonly)    FMDatabase *        facesDatabase;
@property (strong, readonly)    NSString *          libraryBasePath;
@property (strong, readonly)    FMDatabase *        photosDatabase;
@property (strong, readonly)    FMDatabase *        propertiesDatabase;
@property (strong)              NSNumber *          queryOffset;
@property (strong)              NSDictionary *      sourceDictionary;
@property (assign)              BOOL                verboseLogging;

@property (assign)              CGColorSpaceRef     colorspace;
@property (assign)              CGContextRef        bitmapContext;
@property (strong)              CIContext *         ciContext;
@property (strong)              NSArray *           exifDateFormatters;

+ (NSString *) nameFromPath: (NSString *) path;

- (id) initWithPath: (NSString *) path;

- (void) close;

- (NSString *) description;

- (NSString *) displayName;

- (BOOL) open;

- (NSDictionary *) versionExifFromMasterUuid: (NSString *) masterUuid;

- (NSMutableDictionary *) versionExifFromMasterPath: masterPath;

- (NSMutableDictionary *) versionExifFromMasterPath: (NSString *) masterPath
                                        versionUuid: (NSString *) versionUuid
                                    versionFileName: (NSString *) versionFileName
                                        versionName: (NSString *) versionName
                                        versionDate: (NSString *) versionDate;


- (NSString *) versionPathFromMasterPath: (NSString *) masterPath
                             versionUuid: (NSString *) versionUuid
                         versionFileName: (NSString *) versionFileName
                             versionName: (NSString *) versionName;

@end
