//
//  MMFileUtility.m
//  mugmover
//
//  Created by Bob Fitterman on 4/1/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMFileUtility.h"
#import <CommonCrypto/CommonDigest.h>

@implementation MMFileUtility
#pragma mark Class (utility) Methods
/**
 This method extracts Exif data from a local file, return a dictionary. The keys of the
 dictionary have paths that are values like "EXIF", "TIFF", etc. at the first level.
 */
+(NSMutableDictionary*) exifForFileAtPath: (NSString*) filePath
{
    NSMutableDictionary* exifDictionary = nil;
    NSURL* fileUrl = [NSURL fileURLWithPath : filePath];

    if (fileUrl)
    {

        // load the bit image from the file url
        CGImageSourceRef source = CGImageSourceCreateWithURL ( (__bridge CFURLRef) fileUrl, NULL);

        if (source)
        {

            // get image properties into a dictionary
            CFDictionaryRef metadataRef = CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);

            if (metadataRef)
            {

                // cast CFDictonaryRef to NSDictionary
                exifDictionary = [NSMutableDictionary dictionaryWithDictionary : (__bridge NSDictionary *) metadataRef];
                CFRelease(metadataRef);

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

/**
 Returns the byte length of a file.
 */
+ (NSNumber *) lengthForFileAtPath: (NSString *) path
{
    NSError *error;
    NSDictionary *dict = [[NSFileManager defaultManager] attributesOfItemAtPath: path error: &error];
    if (error)
    {
        return nil;
    }
    return [dict objectForKey: NSFileSize];
}

/**
 * From http://stackoverflow.com/questions/1363813/how-can-you-read-a-files-mime-type-in-objective-c
 */
+ (NSString *) mimeTypeForFileAtPath: (NSString *) path
{
    if (![[NSFileManager defaultManager] fileExistsAtPath: path]) {
        return nil;
    }
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[path pathExtension], NULL);
    CFStringRef mimeType = UTTypeCopyPreferredTagWithClass (UTI, kUTTagClassMIMEType);
    CFRelease(UTI);
    if (!mimeType) {
        return @"application/octet-stream";
    }
    return (NSString *)CFBridgingRelease(mimeType);
}
/*
 * From http://stackoverflow.com/questions/10988369/is-there-a-md5-library-that-doesnt-require-the-whole-input-at-the-same-time
 */
+ (NSString *) md5ForFileAtPath: (NSString *) path
{
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath: path];
    if (!handle)
    {
        return nil;
    }

    CC_MD5_CTX md5;
    CC_MD5_Init(&md5);
    CC_LONG const chunkSize = 32000;

    while (YES)
    {
        @autoreleasepool
        {
            NSData *fileData = [handle readDataOfLength: chunkSize ];
            CC_MD5_Update(&md5, [fileData bytes], (CC_LONG)[fileData length]);
            if ([fileData length] == 0)
            {
                break;
            }
        }
    }
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &md5);

    NSString* s = [NSString stringWithFormat: @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                   digest[0], digest[1],
                   digest[2], digest[3],
                   digest[4], digest[5],
                   digest[6], digest[7],
                   digest[8], digest[9],
                   digest[10], digest[11],
                   digest[12], digest[13],
                   digest[14], digest[15]];
    return s;
}

/**
 * Returns the path to a newly-created JPEG file in a newly-created temporary directory.
 * The caller is obliged to do any cleanup (of the file and directory).
 * Returns nil in the event any step fails.
 */
+ (NSString *) temporaryJpegFromPath: (NSString *) imageFile
{
    NSImage *sourceImage = [[NSImage alloc] initWithContentsOfFile: imageFile];
    NSArray *representations = [sourceImage representations];
    NSDictionary *imageProps = [NSDictionary dictionaryWithObject: @0.9
                                                           forKey: NSImageCompressionFactor];
    NSData *bitmapData = [NSBitmapImageRep representationOfImageRepsInArray: representations
                                                                  usingType: NSJPEGFileType
                                                                 properties: imageProps];
    NSString *pathToTemporaryDirectory = [MMFileUtility pathToTemporaryDirectory];
    if (pathToTemporaryDirectory)
    {
        NSString *filePart = [[[imageFile lastPathComponent]
                                    stringByDeletingPathExtension]
                                        stringByAppendingPathExtension: @"jpg"];
        NSString *filePath = [pathToTemporaryDirectory stringByAppendingPathComponent: filePart];
        [bitmapData writeToFile: filePath
                     atomically: YES];
        return filePath;
    }
    return nil;
}

/**
 * Returns a path a temporary directory with a globally unique name
 */
+ (NSString *) pathToTemporaryDirectory
{
    NSError *error;

    NSString *uniqueIdentifier = [[NSProcessInfo processInfo] globallyUniqueString];
    NSString *directoryPath = [NSTemporaryDirectory() stringByAppendingPathComponent:uniqueIdentifier];
    NSURL *directoryUrl = [NSURL fileURLWithPath: directoryPath
                                     isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL: directoryUrl
                             withIntermediateDirectories: YES
                                              attributes: nil
                                                   error: &error];
    if (error)
    {
        DDLogError(@"Error creating temporary directory (%@): %@", directoryPath, error);
        nil;
    }
    return directoryPath;
}


@end
