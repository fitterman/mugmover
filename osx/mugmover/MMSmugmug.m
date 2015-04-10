//
//  MMSmugmug.m
//  Everything to do with Smugmug integration.
//
//  Created by Bob Fitterman on 03/17/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMPhoto.h"
#import "MMLibraryEvent.h"
#import "MMPhoto.h"
#import "MMPhotoLibrary.h"
#import "MMSmugmug.h"
#import "MMOauthSmugmug.h"
#import "MMDataUtility.h"
#import "MMMasterViewController.h"

@implementation MMSmugmug

NSString * const handlePath = @"smugmug.currentAccountHandle";


#define PHOTOS_PER_REQUEST (10)
extern const NSInteger MMDefaultRetries;

NSDictionary       *photoResponseDictionary;
long                retryCount;

/**
 * We are using UUIDs in many places for URL names. The UUID character-space consists
 * of the characters A-Z, a-z, 0-9 and 2 pieces of punctuation: "+", "%", each of which
 * is problematic. We replace "+" with "-" and replace "%" with "--". The UUIDs are
 * short enough they will not exceed the Smugmug limit with this approach. As they 
 * must start with an uppercase letter, we are prefixing them all with "MM"
 */
+ (NSString *) sanitizeUuid: (NSString *) inUrl
{
  return [@"MM" stringByAppendingString: [[inUrl stringByReplacingOccurrencesOfString:@"+" withString:@"-"]
          stringByReplacingOccurrencesOfString:@"%" withString:@"--"]];
}

- (id) initWithHandle: (NSString *) handle
{
    self = [self init];
    if (self)
    {
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
            
            _defaultFolder = [self findOrCreateFolder: [MMSmugmug sanitizeUuid: library.databaseUuid]
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
                                 _currentAccountHandle = _handle;
                                 [defaults setObject: _currentAccountHandle forKey: handlePath];
                             }
                             NSString *atKey = [NSString stringWithFormat: @"smugmug.%@.accessToken", _currentAccountHandle];
                             NSString *tsKey = [NSString stringWithFormat: @"smugmug.%@.tokenSecret", _currentAccountHandle];
                             [defaults setObject: _smugmugOauth.accessToken forKey: atKey];
                             [defaults setObject: _smugmugOauth.tokenSecret forKey: tsKey];
                             _defaultFolder = [self findOrCreateFolder: [MMSmugmug sanitizeUuid: library.databaseUuid]
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
                         }
                     }];
}

#pragma mark "Private methods"

/**
 * Returns the albumId of an album. The identity of the album is determined by the folder path
 * into which it is to be place. The arguments are
 *   +urlName+, which is part of the URL and is constrained by the related rules
 *   +partialPath+ which is the path portion beneath the username, for example "default/foo"
 *                 If +partialPath+ is nil, the album will be created at the top level.
 *   +displayName+ which the displayed title for the album
 */
- (NSString *) findOrCreateAlbum: (NSString *) urlName
                         beneath: (NSString *) partialPath
                     displayName: (NSString *) displayName
                     description: (NSString *) description
{
    NSMutableString *apiRequest = [[NSMutableString alloc] initWithString: @"folder/user/"];
    [apiRequest appendString: _handle];
    if (partialPath)
    {
        [apiRequest appendString: @"/"];
        [apiRequest appendString: partialPath];
    }
    [apiRequest appendString: @"!albums"];
    NSURLRequest *createAlbumRequest = [_smugmugOauth apiRequest: apiRequest
                                                       parameters: @{@"Description":        description,
                                                                     @"UrlName":            urlName,
                                                                     @"UrlName":            urlName,
                                                                     @"Name":               displayName,
                                                                     @"Privacy":            @"Private",
                                                                     @"SmugSearchable":     @"No",
                                                                     @"WorldSearchable":    @"No",
                                                                     }
                                                             verb: @"POST"];
    NSURLResponse *response;
    NSError *error;
    NSInteger retries = MMDefaultRetries;
    while (retries > 0)
    {
        NSData *serverData = [NSURLConnection sendSynchronousRequest: createAlbumRequest
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
            NSString *uri = nil;
            if (httpStatus == 200)
            {
                uri = [parsedServerResponse valueForKeyPath: @"Response.Uri"];
            }
            else if (httpStatus == 409) // Conflict, it exists
            {
                // Cannot use valueForKeyPath because the handle might contain a period
                NSArray *pieces = @[@"Conflicts",
                                    [parsedServerResponse valueForKeyPath: @"Response.Uri"],
                                    @"Album",
                                    @"Uri"];
                NSObject *object = parsedServerResponse;
                for (NSString *piece in pieces)
                {
                    object = [(NSDictionary *)object objectForKey: piece];
                }
                uri = (NSString *)object;
            }
            else
            {
                DDLogError(@"Network error httpStatusCode=%ld", (long)httpStatus);
                retries--;
                DDLogError(@"response=%@", parsedServerResponse);
            }
            if (uri)
            {
                return [[uri componentsSeparatedByString: @"/"] lastObject];
            }
        }
    }
    return nil;
}
 
/**
 * Returns the "urlName" value (one piece of the path) for a folder. If the +levelOneFolder+ is nil
 * the result will be a top-level folder creation. If the +partialPath+ is present, then it will
 * be inserted as part of the path. When used, "+partialPath+ should only contain embedded slashes,
 * no initial or terminal ones, for example: "abc/def".
 * If something really goes wrong, nil is returned.
 */
- (NSString *) findOrCreateFolder: (NSString *) urlName
                          beneath: (NSString *) partialPath
                      displayName: (NSString *) displayName
                      description: (NSString *) description
{
    NSMutableString *apiRequest = [[NSMutableString alloc] initWithString: @"folder/user/"];
    [apiRequest appendString: _handle];
    if (partialPath)
    {
        [apiRequest appendString: @"/"];
        [apiRequest appendString: partialPath];
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
