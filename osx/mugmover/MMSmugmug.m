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
 * We are using UUIDs in many places for URL names. UUIDs have been observed to have two
 * very different forms. Either they are base-64-encoded using the characters
 * A-Z, a-z, 0-9 and 2 pieces of punctuation: "+" and "%", both of which
 * is problematic. We replace "+" with "-" and replace "%" with "--". These UUIDs are
 * short enough they will not exceed the Smugmug limit with this approach. As they 
 * must start with an uppercase letter, we are prefixing them all with "MM".
 *
 * The other form of the UUID is a series of hex digits and dashes, such as
 * "0DA8A4A5-8E40-4D72-A5DC-EC3309EF868C". In this case, we compress out the dashes and
 * then encode the remaining characters in base64.
 */
+ (NSString *) sanitizeUuid: (NSString *) inUuid
{
    if ([inUuid rangeOfString: @"\\A[-0-9A-F]+\\Z"
                      options: NSRegularExpressionSearch|NSCaseInsensitiveSearch].location == NSNotFound)
    {
        // Case 1
        return [@"MM" stringByAppendingString: [[inUuid stringByReplacingOccurrencesOfString:@"+" withString:@"-"]
                                                stringByReplacingOccurrencesOfString:@"%" withString:@"--"]];
    }
    // case 2
    //
    NSString *result = [MMDataUtility parseHexToOurBase64: inUuid];
    if (result)
    {
        // This is intentionally different from the prefix, above, so we can tell how we got here.
        // And our method returns "-" already so we don't need to do that substitution.
        return [@"M-" stringByAppendingString: [result stringByReplacingOccurrencesOfString:@"%" withString:@"--"]];
    }
    NSLog(@"ERROR   Base64 encoding detected bad input value");
    return nil;
}

- (id) initFromDictionary: (NSDictionary *) dictionary
{
    self = [super init];
    if (self)
    if (dictionary && [[dictionary valueForKey: @"type"] isEqualToString: @"smugmug"])
    {
        _uniqueId = [dictionary valueForKey: @"id"];
        _handle = [dictionary valueForKey: @"name"];
        _errorLog = [[NSMutableArray alloc] init];
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
    _errorLog = nil;
    _handle = nil;
    _uniqueId = nil;
}

#pragma mark "Public methods"
/**
 * Adds an error to a sequential log of errors
 */
- (void) logError: (NSError *) error
{
    NSDictionary *logRecord =@{@"time": [NSDate date], @"error": error};
    [_errorLog addObject: logRecord];
}

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
 * Returns the albumId of an album. The identity of the album is determined by the node (folder)
 * into which it is to be placed. The arguments are
 *   +urlName+     which is part of the URL and is constrained by the rules imposed by Smugmug.
 *                 The uniqueness of the urlName is required, and we impose this by using uuid from
 *                 the corresponding event.
 *   +folderId+    which is the ID of a Smugmug node (folder).
 *   +displayName+ which is the displayed title for the album
 *   +options+     allow control of the following
 *                   Visiblity: private/unlisted/inherit*
 *                   Social Show Sharing
 *                   Social Allow Comments
 *                   Social Allow Likes
 *                   Web Searchable
 *                   Smug searchable
 *                   Sort by...
 *                   OR JUST USE A QUICK SETTING!
 
 *                   
 * TODO Change Smugmug searchable to site-setting
 */
- (NSString *) createAlbumWithUrlName: (NSString *) urlName
                             inFolder: (NSString *) folderId
                          displayName: (NSString *) displayName
                          description: (NSString *) description;
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
                                                                    @"AutoRename":         @"Yes",
                                                                    @"Name":               displayName,
                                                                    @"Privacy":            @"Unlisted", // UNLISTED?
                                                                    @"SmugSearchable":     @"No",
                                                                    @"WorldSearchable":    @"No",
                                                                  }
                                                            verb: @"POST"];
    httpStatus = [MMDataUtility makeSyncJsonRequestWithRetries: createAlbumRequest
                                                    parsedData: &parsedServerResponse];
    if (httpStatus == 200)
    {
        uri = [parsedServerResponse valueForKeyPath: @"Response.Uri"];
        if (uri)
        {
            // It's actually an API URL: just get the albumId
            return [uri lastPathComponent];
        }
    }

    DDLogError(@"Network error httpStatusCode=%ld", (long)httpStatus);
    DDLogError(@"response=%@", [_smugmugOauth extractErrorResponseData: parsedServerResponse]);
    return nil;
}

/**
 * Confirms whether an AlbumID exists
 */
- (BOOL) hasAlbumId: (NSString *) albumId
{
    NSDictionary *parsedServerResponse;
    
    NSString *apiRequest = [NSString stringWithFormat: @"album/%@", albumId];
    NSURLRequest *getAlbumRequest = [_smugmugOauth apiRequest: apiRequest
                                                   parameters: @{}
                                                         verb: @"GET"];
    NSInteger httpStatus = [MMDataUtility makeSyncJsonRequestWithRetries: getAlbumRequest
                                                              parsedData: &parsedServerResponse];
    if (httpStatus == 200)
    {
        return YES;
    }
    if (httpStatus == 404)
    {
        return NO;
    }
    DDLogError(@"Network error httpStatusCode=%ld", (long)httpStatus);
    DDLogError(@"response=%@", [_smugmugOauth extractErrorResponseData: parsedServerResponse]);
    return NO;
}

/**
 * Returns the MD5 of the uploaded original file with that ID (if provided and found on service)
 */
- (NSString *) md5ForPhotoId: (NSString *) photoId
{
    if (!photoId)
    {
        return nil;
    }

    NSDictionary *parsedServerResponse;
    
    NSString *apiRequest = [NSString stringWithFormat: @"image/%@", photoId];
    NSURLRequest *getImageRequest = [_smugmugOauth apiRequest: apiRequest
                                                   parameters: @{}
                                                         verb: @"GET"];
    NSInteger httpStatus = [MMDataUtility makeSyncJsonRequestWithRetries: getImageRequest
                                                              parsedData: &parsedServerResponse];
    if (httpStatus == 200)
    {
        return [parsedServerResponse valueForKeyPath: @"Response.Image.ArchivedMD5"];
    }
    if (httpStatus != 404)
    {
        DDLogError(@"Network error httpStatusCode=%ld", (long)httpStatus);
        DDLogError(@"response=%@", [_smugmugOauth extractErrorResponseData: parsedServerResponse]);
    }
    return nil;
}

/**
 * Deletes an album from the service, returning YES to indicate success or NO for failure.
 */
- (BOOL) deleteAlbumId: (NSString *) albumId
{
    NSDictionary *parsedServerResponse;
    
    NSString *apiRequest = [NSString stringWithFormat: @"album/%@", albumId];
    NSURLRequest *deleteAlbumRequest = [_smugmugOauth apiRequest: apiRequest
                                                      parameters: @{}
                                                            verb: @"DELETE"];
    NSInteger httpStatus = [MMDataUtility makeSyncJsonRequestWithRetries: deleteAlbumRequest
                                                              parsedData: &parsedServerResponse];
    if (httpStatus == 200)
    {
        return YES;
    }
    DDLogError(@"Network error httpStatusCode=%ld", (long)httpStatus);
    DDLogError(@"response=%@", [_smugmugOauth extractErrorResponseData: parsedServerResponse]);
    return NO;
}

/**
 * Deletes an image from the service, returning YES to indicate success or NO for failure.
 */
- (BOOL) deletePhotoId: (NSString *) photoId
{
    NSDictionary *parsedServerResponse;
    
    NSString *apiRequest = [NSString stringWithFormat: @"image/%@", photoId];
    NSURLRequest *deleteImageRequest = [_smugmugOauth apiRequest: apiRequest
                                                   parameters: @{}
                                                         verb: @"DELETE"];
    NSInteger httpStatus = [MMDataUtility makeSyncJsonRequestWithRetries: deleteImageRequest
                                                              parsedData: &parsedServerResponse];
    if (httpStatus == 200)
    {
        return YES;
    }
    DDLogError(@"Network error httpStatusCode=%ld", (long)httpStatus);
    DDLogError(@"response=%@", [_smugmugOauth extractErrorResponseData: parsedServerResponse]);
    return NO;
}

/**
 * Gets image size details
 */
- (NSDictionary *) imageSizesForPhotoId: (NSString *) photoId
{
    if (!photoId)
    {
        return nil;
    }
    
    NSDictionary *parsedServerResponse;
    
    NSString *apiRequest = [NSString stringWithFormat: @"image/%@-0!sizedetails", photoId];
    NSURLRequest *getImageRequest = [_smugmugOauth apiRequest: apiRequest
                                                   parameters: @{}
                                                         verb: @"GET"];
    NSInteger httpStatus = [MMDataUtility makeSyncJsonRequestWithRetries: getImageRequest
                                                              parsedData: &parsedServerResponse];
    if (httpStatus == 200)
    {
        return [parsedServerResponse valueForKeyPath: @"Response.ImageSizeDetails"];
    }
    if (httpStatus != 404)
    {
        DDLogError(@"Network error httpStatusCode=%ld", (long)httpStatus);
        DDLogError(@"response=%@", [_smugmugOauth extractErrorResponseData: parsedServerResponse]);
    }
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
 * If anything goes seriously wrong, before the completionCallback can be invoked, nil is returned.
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
    NSCharacterSet *goodChars = [NSCharacterSet alphanumericCharacterSet];
    NSCharacterSet *badChars = goodChars.invertedSet;
    NSString *urlName = [[[library displayName] componentsSeparatedByCharactersInSet:badChars]
                                                componentsJoinedByString:@"-"];
    // Punctuation can turn into a dash as well, so we remove all the doubled-up dashes
    // until they are all gone.
    while ([urlName rangeOfString:@"--"].location != NSNotFound)
    {
        urlName = [urlName stringByReplacingOccurrencesOfString:@"--"
                                                     withString:@"-"];
    }

    // From http://stackoverflow.com/questions/2952298/how-can-i-truncate-an-nsstring-to-a-set-length
    // We need to consider multi-byte characters, although the URL may choke the service API anyway
    NSRange stringRange = {0, MIN([urlName length], 28)}; // (28 = 31 - 3, reserving for "MM-")
    // adjust the range to include dependent chars
    stringRange = [urlName rangeOfComposedCharacterSequencesForRange: stringRange];
    urlName = [[urlName substringWithRange: stringRange] lowercaseString];
    // We are obligated to have a name that starts with an uppercase-letter...
    urlName = [NSString stringWithFormat:@"MM-%@", urlName];

    NSURLRequest *createFolderRequest = [_smugmugOauth apiRequest: apiRequest
                                                   parameters: @{@"Description":        [library description],
                                                                 @"Name":               [library displayName],
                                                                 @"Privacy":            @"Unlisted",
                                                                 @"SmugSearchable":     @"No",
                                                                 @"SortIndex":          @"SortIndex",
                                                                 @"UrlName":            urlName,
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
