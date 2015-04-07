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
@class MMSmugmug;

@interface MMPhotoLibrary : NSObject

@property (strong, readonly)    NSString *          databaseAppId;
@property (strong, readonly)    NSString *          databaseUuid;
@property (strong, readonly)    NSString *          databaseVersion;
@property (strong, readonly)    NSString *          libraryBasePath;
@property (strong, readonly)    FMDatabase *        facesDatabase;
@property (strong, readonly)    FMDatabase *        photosDatabase;
@property (strong)              MMSmugmug *         serviceApi;
@property (strong)              NSDictionary *      sourceDictionary;
@property (assign)              BOOL                verboseLogging;

@property (assign)              CGColorSpaceRef     colorspace;
@property (assign)              CGContextRef        bitmapContext;
@property (strong)              CIContext *         ciContext;
@property (strong)              NSArray *           exifDateFormatters;

- (id) initWithPath: (NSString *) path;

- (void) close;

- (NSString *) description;

- (NSString *) displayName;

- (NSDictionary *) versionExifFromMasterUuid: (NSString *) masterUuid;

- (NSMutableDictionary *) versionExifFromMasterPath: masterPath;

- (NSMutableDictionary *) versionExifFromMasterPath: (NSString *) masterPath
                                        versionUuid: (NSString *) versionUuid
                                    versionFilename: (NSString *) versionFilename
                                        versionName: (NSString *) versionName;


- (NSString *) versionPathFromMasterPath: (NSString *) masterPath
                             versionUuid: (NSString *) versionUuid
                         versionFilename: (NSString *) versionFilename
                             versionName: (NSString *) versionName;

@end
