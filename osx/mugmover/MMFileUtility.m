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

+ (NSNumber *) lengthForFileAtPath: (NSString *) path
{
    NSError *error;
    NSDictionary *dict = [[NSFileManager defaultManager] attributesOfItemAtPath: path error: &error];
    if (error)
    {
        return nil;
    }
    return [dict objectForKey:NSFileSize];
}

@end
