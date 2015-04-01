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
extern const NSInteger MMDefaultRetries;

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
        _streamQueue = [NSOperationQueue mainQueue];
        _photoDictionary = [[NSMutableDictionary alloc] init];
        if (!_photoDictionary)
        {
            [self close];
            return nil;
        }
        _handle = handle;
        _currentPhotoIndex = (_page - 1) * PHOTOS_PER_REQUEST;
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        _currentAccountHandle = [defaults stringForKey: @"smugmug.currentAccountHandle"];
        if (_currentAccountHandle)
        {
            NSString *atKey = [NSString stringWithFormat: @"smugmug.%@.accessToken", _currentAccountHandle];
            NSString *tsKey = [NSString stringWithFormat: @"smugmug.%@.tokenSecret", _currentAccountHandle];
            _smugmugOauth = [[MMOauthSmugmug alloc] initWithStoredToken: [defaults objectForKey: atKey]
                                                                 secret: [defaults objectForKey: tsKey]];

            // Now try to find the default folder. If that fails, force a whole login process again,
            // because either the token has been revoked or the permissions were reduced manually by
            // the user.
            _defaultFolder = [self createOrFindDefaultFolder];
            if (!_defaultFolder) // Still not set? Reset the authorization
            {
                _smugmugOauth = nil;
            }
            else
            {
                NSString *dfKey = [NSString stringWithFormat: @"smugmug.%@.defaultFolder", _currentAccountHandle];
                [defaults setObject: _defaultFolder forKey: dfKey];
            }
            [defaults synchronize];
        }
        if (_smugmugOauth)
        {
            return self;
        }

        // Otherwise we start the whole process over again...
        _smugmugOauth = [[MMOauthSmugmug alloc] initAndStartAuthorization: ^(Float32 progress, NSString *text)
        {
            self.initializationProgress = progress;
            if (progress == 1.0)
            {
                _currentAccountHandle = [defaults stringForKey: @"smugmug.currentAccountHandle"];
                if (!_currentAccountHandle)
                {
                    _currentAccountHandle = @"jayphillipsstudio";
                    [defaults setObject: _currentAccountHandle forKey: @"smugmug.currentAccountHandle"];
                }
                NSString *atKey = [NSString stringWithFormat: @"smugmug.%@.accessToken", _currentAccountHandle];
                NSString *tsKey = [NSString stringWithFormat: @"smugmug.%@.tokenSecret", _currentAccountHandle];
                [defaults setObject: _smugmugOauth.accessToken forKey: atKey];
                [defaults setObject: _smugmugOauth.tokenSecret forKey: tsKey];
                _defaultFolder = [self createOrFindDefaultFolder];
                if (!_defaultFolder) // Still not set? report error
                {
                    DDLogError(@"unable to create default folder");
                }
                else
                {
                    NSString *dfKey = [NSString stringWithFormat: @"smugmug.%@.defaultFolder", _currentAccountHandle];
                    [defaults setObject: _defaultFolder forKey: dfKey];
                }
                [defaults synchronize];


/**
                NSString *path = @"/Users/Bob/Downloads/JULIUS STUCHINSKY WW1 Draft Registration 1917-1918.jpg";
                NSURLRequest *uploadRequest = [_smugmugOauth upload: path
                                                           albumUid: @"4RTMrj"
                                                              title: nil
                                                            caption: nil
                                                               tags: nil];
                ServiceResponseHandler processSmugmugUpload = ^(NSDictionary *responseDictionary)
                {
                    DDLogError(@"responseDictionary=%@", responseDictionary);
                };
                [_smugmugOauth  processUrlRequest:  uploadRequest
                                            queue: _streamQueue
                                remainingAttempts: MMDefaultRetries
                                completionHandler: processSmugmugUpload];
   */
            }
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
    _currentAccountHandle = nil;
    _defaultFolder = nil;
    _handle = nil;
    _library = nil;
    _photoDictionary = nil;
    _streamQueue = nil;
}

#pragma mark "Private methods"

- (NSString *) createOrFindDefaultFolder
{
    NSURLRequest *createFolderRequest = [_smugmugOauth apiRequest: @"folder/user/jayphillips!folders"
                                                       parameters: @{@"Description":        @"Photos via MugMover from...",
                                                                     @"Name":               @"Photo Library Name",
                                                                     @"Privacy":            @"Private",
                                                                     @"SmugSearchable":     @"No",
                                                                     @"SortIndex":          @"SortIndex",
                                                                     @"UrlName":            [_library.databaseUuid uppercaseString],
                                                                     @"WorldSearchable":    @"No",
                                                                     }
                                                             verb: @"POST"];
    NSURLResponse *response;
    NSError *error;
    NSInteger retries = MMDefaultRetries;
    while (retries > 0)
    {
        NSData *serverData = [NSURLConnection sendSynchronousRequest: createFolderRequest
                                                   returningResponse: &response
                                                               error: &error];
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (error)
        {
            DDLogError(@"System error: %@", error);
            retries--;
        }
        else
        {
            NSDictionary *parsedServerResponse = [MMOauthAbstract parseJsonData: serverData];
            NSInteger httpStatus = [httpResponse statusCode];
            if (httpStatus == 200)
            {
                return [parsedServerResponse valueForKeyPath: @"Response.Folder.UrlName"];
            }
            else if (httpStatus == 409) // Conflict, it exists
            {
                // Cannot use valueFOrKeyPath because the handle might contain a period
                NSArray *pieces = @[@"Conflicts",
                                    [parsedServerResponse valueForKeyPath: @"Response.Uri"],
                                    @"Folder",
                                    @"UrlName"];
                NSObject *object = parsedServerResponse;
                for (NSString *piece in pieces)
                {
                    object = [(NSDictionary *)object objectForKey: piece];
                }
                return (NSString *)object;
            }
            else
            {
                DDLogError(@"Network error httpStatusCode=%ld", (long)httpStatus);
                retries--;
                DDLogError(@"response=%@", parsedServerResponse);
            }
        }
    }
    return nil;
}
@end
