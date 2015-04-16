//
//  MMFileUtility.h
//  mugmover
//
//  Created by Bob Fitterman on 4/1/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MMFileUtility : NSObject

+ (NSMutableDictionary*) exifForFileAtPath: (NSString*) filePath;

+ (NSNumber *) lengthForFileAtPath: (NSString *) path;

+ (NSString *) md5ForFileAtPath: (NSString *) path;

+ (NSString *) mimeTypeForFileAtPath: (NSString *) path;

+ (NSString *) pathToTemporaryDirectory;

+ (NSString *) temporaryJpegFromPath: (NSString *) imageFile;

@end
