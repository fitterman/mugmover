//
//  MMSmugmug.m
//  Everything to do with Smugmug integration.
//
//  Created by Bob Fitterman on 03/17/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMPhoto.h"
#import "MMLibraryEvent.h"
#import "MMPhotoLibrary.h"
#import "MMSmugmug.h"
#import "MMOauthSmugmug.h"
#import "MMDataUtility.h"

@implementation MMSmugmug

NSString * const handlePath = @"smugmug.currentAccountHandle";


#define PHOTOS_PER_REQUEST (10)
extern const NSInteger MMDefaultRetries;

NSDictionary       *photoResponseDictionary;
long                retryCount;

- (id) initWithHandle: (NSString *) handle
{
    self = [self init];
    if (self)
    {
        _isUploading = NO;
        if (!handle)
        {
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
    }
    return self;
}

- (void) close
{
    _accessSecret = nil;
    _accessToken = nil;
    _currentPhoto = nil;
    _currentAccountHandle = nil;
    _defaultFolder = nil;
    _handle = nil;
    _photoDictionary = nil;
    _streamQueue = nil;
}

#pragma mark "Public methods"
/**
 This either reconsitutes an Oauth token from the stored preferences (NSDefault) or
 triggers a new Oauth dance. You know the outcome by observing "initializationProgress".
 */

- (void) configureOauthForLibrary: (MMPhotoLibrary *) library
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _currentAccountHandle = [defaults stringForKey: handlePath];
    if (_currentAccountHandle)
    {
        NSString *atKey = [NSString stringWithFormat: @"smugmug.%@.accessToken", _currentAccountHandle];
        NSString *tsKey = [NSString stringWithFormat: @"smugmug.%@.tokenSecret", _currentAccountHandle];
        _smugmugOauth = [[MMOauthSmugmug alloc] initWithStoredToken: [defaults objectForKey: atKey]
                                                             secret: [defaults objectForKey: tsKey]];
        if (_smugmugOauth)
        {
            self.initializationProgress = 1.0; // Mark it as completed
            // Now try to find the default folder. If that fails, force a whole login process again,
            // because either the token has been revoked or the permissions were reduced manually by
            // the user.
            
            _defaultFolder = [self findOrCreateFolder: [library.databaseUuid uppercaseString]
                                              beneath: nil
                                          displayName: [library displayName]
                                          description: [library description]];
            if (!_defaultFolder) // Still not set? Reset the authorization
            {
                _smugmugOauth = nil;
            }
            else
            {
                NSString *dfKey = [NSString stringWithFormat: @"smugmug.%@.defaultFolder", _currentAccountHandle];
                [defaults setObject: _defaultFolder forKey: dfKey];
                library.serviceApi = self;
            }
        }
        else
        {
            [defaults removeObjectForKey: atKey];
            [defaults removeObjectForKey: tsKey];
            [defaults removeObjectForKey: handlePath];
        }
        [defaults synchronize];
    }
    if (_smugmugOauth)
    {
        return; // after synchronize
    }

    // Otherwise we start the whole process over again...
    _smugmugOauth = [[MMOauthSmugmug alloc] initAndStartAuthorization: ^(Float32 progress, NSString *text)
                     {
                         self.initializationProgress = progress;
                         if (progress == 1.0)
                         {
                             _currentAccountHandle = [defaults stringForKey: handlePath];
                             if (!_currentAccountHandle)
                             {
                                 _currentAccountHandle = @"jayphillipsstudio";
                                 [defaults setObject: _currentAccountHandle forKey: handlePath];
                             }
                             NSString *atKey = [NSString stringWithFormat: @"smugmug.%@.accessToken", _currentAccountHandle];
                             NSString *tsKey = [NSString stringWithFormat: @"smugmug.%@.tokenSecret", _currentAccountHandle];
                             [defaults setObject: _smugmugOauth.accessToken forKey: atKey];
                             [defaults setObject: _smugmugOauth.tokenSecret forKey: tsKey];
                             _defaultFolder = [self findOrCreateFolder: [library.databaseUuid uppercaseString]
                                                               beneath: nil
                                                           displayName: [library displayName]
                                                           description: [library description]];
                             if (!_defaultFolder) // Still not set? report error
                             {
                                 DDLogError(@"unable to create default folder");
                             }
                             else
                             {
                                 NSString *dfKey = [NSString stringWithFormat: @"smugmug.%@.defaultFolder", _currentAccountHandle];
                                 [defaults setObject: _defaultFolder forKey: dfKey];
                                 library.serviceApi = self;
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
- (BOOL) startUploading: (NSArray *) photos
               forEvent: (MMLibraryEvent *) event
{
    if (_isUploading)
    {
        return NO;
    }
    _isUploading = YES;
    NSString *name = [event name];
    if (!name)
    {
        name = [event dateRange];
    }
    NSString *newFolder = [self findOrCreateFolder: [[event uuid] uppercaseString]
                                           beneath: _defaultFolder
                                       displayName: [event name]
                                       description: @"Photos uploaded via Mugmover"];    
    return YES;
}
#pragma mark "Private methods"

/**
 * Returns the "urlName" value (one piece of the path) for a folder. If the +levelOneFolder+ is nil
 * the result will be a top-level folder creation. If the +levelOneFolder+ is present, then it will
 * be inserted as part of the path.
 * If something really goes wrong, nil is returned.
 */
- (NSString *) findOrCreateFolder: (NSString *) urlName
                          beneath: (NSString *) levelOneFolder
                      displayName: (NSString *) displayName
                      description: (NSString *) description
{
    NSMutableString *apiRequest = [@"folder/user/jayphillips" mutableCopy];
    if (levelOneFolder)
    {
        [apiRequest appendString: @"/"];
        [apiRequest appendString: levelOneFolder];
    }
    [apiRequest appendString: @"!folders"];
    NSURLRequest *createFolderRequest = [_smugmugOauth apiRequest: apiRequest
                                                       parameters: @{@"Description":        description,
                                                                     @"Name":               displayName,
                                                                     @"Privacy":            @"Private",
                                                                     @"SmugSearchable":     @"No",
                                                                     @"SortIndex":          @"SortIndex",
                                                                     @"UrlName":            urlName,
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
            NSDictionary *parsedServerResponse = [MMDataUtility parseJsonData: serverData];
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
