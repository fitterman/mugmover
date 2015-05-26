//
//  MMSmugmug.m
//  Everything to do with Smugmug integration.
//
//  Created by Bob Fitterman on 03/17/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMSmugmug.h"
#import "MMPhotoLibrary.h"
#import "MMPrefsManager.h"
#import "MMOauthSmugmug.h"
#import "MMDataUtility.h"

@implementation MMSmugmug


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

- (id) initFromDictionary: (NSDictionary *) dictionary
{
    self = [super init];
    if (self)
    if (dictionary && [[dictionary valueForKey: @"type"] isEqualToString: @"smugmug"])
    {
        _uniqueId = [dictionary valueForKey: @"id"];
        _handle = [dictionary valueForKey: @"name"];
        [self configureOauthRetryOnFailure: NO];
        if (!_smugmugOauth)
        {
            [self close];
            self = nil;
        }
    }
    return self;
}

/**
 * To use this, just create an instance of this class and invoke this method with a block
 * that expects a BOOL. The BOOL is indicative of the outcome with YES meaning the authentication
 * completed. NO would indicate it failed.
 *
 * Save away the state and reconstitute it with a call to configureOauthWithLibrary:.
 */
- (void) authenticate: (void (^) (BOOL)) completionHandler
{
    _smugmugOauth = [[MMOauthSmugmug alloc] initAndStartAuthorization: ^(Float32 progress, NSString *text)
                     {
                         if (progress == 1.0)
                         {
                             completionHandler([self getUserInfo]);
                         }
                         else if (progress == -1.0)
                         {
                             completionHandler(NO);
                         }
                     }];
}

- (NSString *) name
{
    return [NSString stringWithFormat: @"%@ (Smugmug)\n%@", _handle, _uniqueId];
}

- (NSDictionary *) serialize
{
    return @{@"type":   @"smugmug",
              @"id":     _uniqueId,
             @"name":   (!_handle ? @"(none)" : _handle)};
}

- (void) close
{
    _accessSecret = nil;
    _accessToken = nil;
    _currentPhoto = nil;
    _handle = nil;
    _uniqueId = nil;
}

#pragma mark "Public methods"
/**
 This either reconsitutes an Oauth token from the stored preferences (NSUserDefaults) or
 triggers a new Oauth dance. You know the outcome by observing "initializationProgress".
 */

- (void) configureOauthRetryOnFailure: (BOOL) attemptRetry
{
    if (_uniqueId)
    {
        NSArray *tokenAndSecret = [MMPrefsManager tokenAndSecretForService: @"smugmug"
                                                                  uniqueId: _uniqueId];
        if (tokenAndSecret[0] && tokenAndSecret[1])
        {
            _smugmugOauth = [[MMOauthSmugmug alloc] initWithStoredToken: tokenAndSecret[0]
                                                                 secret: tokenAndSecret[1]];
        }
        else
        {
            _smugmugOauth = nil;
        }
        if (!_smugmugOauth)
        {
            [MMPrefsManager clearTokenAndSecretForService: @"smugmug"
                                                 uniqueId: _uniqueId];
        }
    }
    if (_smugmugOauth || !attemptRetry)
    {
        return; // after synchronize
    }

    // Otherwise we start the whole process over again...
    _smugmugOauth = [[MMOauthSmugmug alloc] initAndStartAuthorization: ^(Float32 progress, NSString *text)
                     {
                         DDLogInfo(@"progress=%f", progress);
                         if (progress == 1.0)
                         {
                             DDLogInfo(@"progress=1.0");
                         }
                         else
                         {
                             DDLogInfo(@"progress!=1.0");
                         }
                     }];
}


/**
 * Returns a BOOL indicating whether it was able to obtain user information via the API.
 */
- (BOOL) getUserInfo
{
    NSDictionary *parsedServerResponse;
    NSURLRequest *userInfoRequest = [_smugmugOauth apiRequest: @"!authuser"
                                                   parameters: nil
                                                        verb: @"GET"];
    NSInteger httpStatus =  [MMDataUtility makeSyncJsonRequestWithRetries: userInfoRequest
                                                               parsedData: &parsedServerResponse];
    if (httpStatus == 200)
    {
        _uniqueId = [parsedServerResponse valueForKeyPath: @"Response.User.RefTag"];
        _handle = [parsedServerResponse valueForKeyPath: @"Response.User.NickName"];
        return YES;
    }
    else
    {
        DDLogError(@"Network error httpStatusCode=%ld", (long)httpStatus);
        DDLogError(@"response=%@", [_smugmugOauth extractErrorResponseData: parsedServerResponse]);
        return NO;
    }
}

#pragma mark "Private methods"

/**
 * Returns the albumId of an album. The identity of the album is determined by the node
 * into which it is to be placed. The arguments are
 *   +urlName+, which is part of the URL and is constrained by the rules imposed by Smugmug.
 *          The uniqueness of the urlName is required, and we impose this by using uuid from
 *          the corresponding event.
 *   +folderId+ which an ID of a Smugmug node.
 *   +displayName+ which the displayed title for the album
 */
- (NSString *) findOrCreateAlbum: (NSString *) urlName
                        inFolder: (NSString *) folderId
                     displayName: (NSString *) displayName
                     description: (NSString *) description
{
    // We have to do this in 2 steps: get the folder, then get the album info
    // because the folder/id API method doesn't support the !albums request.
    NSDictionary *parsedServerResponse;

    NSString *apiRequest = [NSString stringWithFormat: @"folder/id/%@", folderId];
    NSURLRequest *getFolderRequest = [_smugmugOauth apiRequest: apiRequest
                                                    parameters: @{}
                                                          verb: @"GET"];
    NSInteger httpStatus = [MMDataUtility makeSyncJsonRequestWithRetries: getFolderRequest
                                                              parsedData: &parsedServerResponse];
    if (httpStatus != 200)
    {
        DDLogError(@"Network error httpStatusCode=%ld", (long)httpStatus);
        DDLogError(@"response=%@", [_smugmugOauth extractErrorResponseData: parsedServerResponse]);
        return nil;
    }
        
    NSString *uri = nil;
    
    // Our API does not work with full paths, so... we have to strip off the "/api/v2/" part
    NSString *fullPath = [parsedServerResponse  valueForKeyPath: @"Response.Folder.Uri"];
    fullPath = [fullPath substringFromIndex:[@"/api/v2/" length]];
    apiRequest = [NSString stringWithFormat: @"%@!albums", fullPath];
    NSURLRequest *createAlbumRequest = [_smugmugOauth apiRequest: apiRequest
                                                      parameters: @{@"Description":        description,
                                                                    @"UrlName":            urlName,
                                                                    @"Name":               displayName,
                                                                    @"Privacy":            @"Private",
                                                                    @"SmugSearchable":     @"No",
                                                                    @"WorldSearchable":    @"No",
                                                                  }
                                                            verb: @"POST"];
    httpStatus = [MMDataUtility makeSyncJsonRequestWithRetries: createAlbumRequest
                                                    parsedData: &parsedServerResponse];
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
    
    if (uri)
    {
        // It's actually an API URL: just get the albumId
        return [uri lastPathComponent];
    }

    DDLogError(@"Network error httpStatusCode=%ld", (long)httpStatus);
    DDLogError(@"response=%@", [_smugmugOauth extractErrorResponseData: parsedServerResponse]);
    return nil;
}

/**
 * This method returns the Folder ID of the preferred folder under which all the uploaded
 * albums will be created.
 * 1. This queries the defaults (preferences) to see if a folder ID has been stored.
 * 2. If the folder has been stored, an attempt will be made to access the folder. If it works,
 *    the callback is invoked with the folder ID. The call returns.
 * 3. If the folder can't be accessed or a folder ID hasn't been stored, a new folder is created.
 *    Its ID is stored as a default (preference) for future access by this method.
 * If anything goes seriously wrong, before the completionCallback can be invoked, an NSError object
 * is returned.
 */
- (NSString *) findOrCreateFolderForLibrary: (MMPhotoLibrary *) library
{
  
    // 1. Find the preferences. See what it holds
    NSString *folderKey = [NSString stringWithFormat: @"smugmug.%@.folder.%@",
                           _uniqueId,
                          [library databaseUuid]];
    NSString *folderId = [MMPrefsManager objectForKey: folderKey];
    NSString *apiRequest = nil;
    NSDictionary *parsedServerResponse;
    if (folderId)
    {
        // 2. Try to get the folder just to see it's still present.
        apiRequest = [NSString stringWithFormat: @"folder/id/%@", folderId];
        NSURLRequest *getFolderAlbumsRequest = [_smugmugOauth apiRequest: apiRequest
                                                              parameters: @{}
                                                                    verb: @"GET"];
        NSInteger status = [MMDataUtility makeSyncJsonRequestWithRetries: getFolderAlbumsRequest
                                                              parsedData: &parsedServerResponse];
        if (status == 200)
        {
            return folderId;
        }
        DDLogError(@"Error status=%ld", (long)status);
        DDLogError(@"response=%@", [_smugmugOauth extractErrorResponseData: parsedServerResponse]);
    }

    // 3. Create a new folder, use it.
    apiRequest = [NSString stringWithFormat: @"folder/user/%@!folders", _handle];
    NSURLRequest *createFolderRequest = [_smugmugOauth apiRequest: apiRequest
                                                       parameters: @{@"Description":        [library description],
                                                                     @"Name":               [library displayName],
                                                                     @"Privacy":            @"Private",
                                                                     @"SmugSearchable":     @"No",
                                                                     @"SortIndex":          @"SortIndex",
                                                                     @"UrlName":            [MMSmugmug sanitizeUuid: [library databaseUuid]],
                                                                     @"WorldSearchable":    @"No",
                                                                     }
                                                             verb: @"POST"];
    NSInteger httpStatus =  [MMDataUtility makeSyncJsonRequestWithRetries: createFolderRequest
                                                               parsedData: &parsedServerResponse];
    if (httpStatus == 200)
    {
        folderId = [parsedServerResponse valueForKeyPath: @"Response.Folder.Uris.Node.Uri"];
    }
    if (httpStatus == 409) // Conflict, it exists
    {
        // Cannot use [NSDictionary -valueFOrKeyPath:] because the handle might contain a period
        NSArray *pieces = @[@"Conflicts",
                            [parsedServerResponse valueForKeyPath: @"Response.Uri"],
                            @"Folder",
                            @"Uris",
                            @"Node",
                            @"Uri"];
        NSObject *object = parsedServerResponse;
        for (NSString *piece in pieces)
        {
            object = [(NSDictionary *)object objectForKey: piece];
        }
        folderId = (NSString *)object;
    }
    if (folderId)
    {
        // It's actually an API URL: just get the nodeId
        folderId = [folderId lastPathComponent];
        
        // Store it in the defaults
        [MMPrefsManager setObject: folderId forKey: folderKey];
        
        // If it was found or created: send it back
        return folderId;
    }
    
    // Otherwise things went badly...
    DDLogError(@"Network error httpStatusCode=%ld", (long)httpStatus);
    DDLogError(@"response=%@", [_smugmugOauth extractErrorResponseData: parsedServerResponse]);
    return nil; // Signals you completed and failed.
}

@end
