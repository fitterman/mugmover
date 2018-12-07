//
//  MMFileUtility.h
//  mugmover
//
//  Created by Bob Fitterman on 4/1/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MMFileUtility : NSObject

+ (NSString *) bashEscapedString: (NSString *) inString;

+ (NSString *) copyFileAtPath: (NSString *) imageFile
                  toDirectory: (NSString *) directory;

+ (NSMutableDictionary*) exifForFileAtPath: (NSString*) filePath;

+ (NSString *) jpegFromPath: (NSString *) imageFile
                toDirectory: (NSString *) directory;

+ (NSNumber *) lengthForFileAtPath: (NSString *) path;

+ (NSString *) md5ForFileAtPath: (NSString *) path;

+ (NSString *) mimeTypeForFileAtPath: (NSString *) path;

+ (NSString *) pathToTemporaryDirectory;

+ (BOOL) setTimestampsTo: (NSString *)dateString
           forFileAtPath: (NSString *)destPath;


@end
