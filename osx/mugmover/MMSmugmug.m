//
//  MMSmugmug.m
//  Everything to do with Smugmug integration.
//
//  Created by Bob Fitterman on 03/17/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMPhoto.h"
#import "MMPhotoLibrary.h"
#import "MMSmugmug.h"
#import "MMOauthSmugmug.h"

@implementation MMSmugmug


#define PHOTOS_PER_REQUEST (10)

NSDictionary       *photoResponseDictionary;
long                retryCount;

- (id) initWithHandle: (NSString *) handle
          libraryPath: (NSString *) libraryPath
{
    self = [self init];
    if (self)
    {
        if (!handle || !libraryPath)
        {
            return nil;
        }
        _library = [[MMPhotoLibrary alloc] initWithPath: (NSString *) libraryPath];
        if (!_library)
        {
            [self close];
            return nil;
        }

        _photoDictionary = [[NSMutableDictionary alloc] init];
        if (!_photoDictionary)
        {
            [self close];
            return nil;
        }
        _handle = handle;
        _currentPhotoIndex = (_page - 1) * PHOTOS_PER_REQUEST;
        _smugmugOauth = [[MMOauthSmugmug alloc] initAndStartAuthorization: ^(Float32 progress, NSString *text)
        {
            self.initializationProgress = progress;
        }];
    }
    return self;
}

- (void) close
{
    if (_library)
    {
        [_library close];
    }
    _accessSecret = nil;
    _accessToken = nil;
    _currentPhoto = nil;
    _handle = nil;
    _library = nil;
    _photoDictionary = nil;
    _streamQueue = nil;
}

@end
