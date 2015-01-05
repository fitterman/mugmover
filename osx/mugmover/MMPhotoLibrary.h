//
//  MMPhotoLibrary.h
//  mugmover
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FMDatabase;

@interface MMPhotoLibrary : NSObject

@property (strong) FMDatabase *             facesDatabase;
@property (strong) FMDatabase *             photosDatabase;

- (id)initWithPath:(NSString *)value;

- (NSDictionary *) versionExifFromMasterUuid: (NSString *) masterUuid;

+ (NSDictionary *) versionExifFromMasterPath: masterPath;

+ (NSDictionary *) versionExifFromMasterPath: masterPath
                                 versionUuid: versionUuid
                             versionFilename: versionFilename;

@end
