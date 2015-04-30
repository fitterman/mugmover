//
//  MMSmugmug.m
//  Everything to do with Smugmug integration.
//
//  Created by Bob Fitterman on 03/17/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMSmugmug.h"
#import "MMOauthSmugmug.h"
#import "MMDataUtility.h"
#import "MMMasterViewController.h"

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
    // WIPE THE DEFAULTS:[[NSUserDefaults standardUserDefaults] removePersistentDomainForName:[[NSBundle mainBundle] bundleIdentifier]];
    if (_uniqueId)
    {
        NSString *atKey = [NSString stringWithFormat: @"smugmug.%@.accessToken", _uniqueId];
        NSString *tsKey = [NSString stringWithFormat: @"smugmug.%@.tokenSecret", _uniqueId];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        _smugmugOauth = [[MMOauthSmugmug alloc] initWithStoredToken: [defaults objectForKey: atKey]
                                                             secret: [defaults objectForKey: tsKey]];
        if (!_smugmugOauth)
        {
            [defaults removeObjectForKey: atKey];
            [defaults removeObjectForKey: tsKey];
            [defaults synchronize];
        }
    }
    if (_smugmugOauth || !attemptRetry)
    {
        return; // after synchronize
    }

    // Otherwise we start the whole process over again...
    _smugmugOauth = [[MMOauthSmugmug alloc] initAndStartAuthorization: ^(Float32 progress, NSString *text)
                     {
                         NSLog(@"progress=%f", progress);
                         if (progress == 1.0)
                         {
                             NSLog(@"progress=1.0");
                         }
                         else
                         {
                             NSLog(@"progress!=1.0");
                         }
                     }];
}


/**
 * Returns a BOOL indicating whether it was able to obtain user information via the API.
 */
- (BOOL) getUserInfo
{
    NSURLRequest *userInfoRequest = [_smugmugOauth apiRequest: @"!authuser"
                                                   parameters: nil
                                                        verb: @"GET"];
    NSURLResponse *response;
    NSError *error;
    NSInteger retries = MMDefaultRetries;
    while (retries-- > 0)
    {
        NSData *serverData = [NSURLConnection sendSynchronousRequest: userInfoRequest
                                                   returningResponse: &response
                                                               error: &error];
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (error)
        {
            DDLogError(@"System error: %@", error);
            continue;
        }
        NSDictionary *parsedServerResponse = [MMDataUtility parseJsonData: serverData];
        NSInteger httpStatus = [httpResponse statusCode];
        if (httpStatus == 200)
        {
            _uniqueId = [parsedServerResponse valueForKeyPath: @"Response.User.RefTag"];
            _handle = [parsedServerResponse valueForKeyPath: @"Response.User.NickName"];
            return YES;
        }
        else
        {
            DDLogError(@"Network error httpStatusCode=%ld", (long)httpStatus);
            DDLogError(@"response=%@", [_smugmugOauth extractErrorResponseData: serverData]);
            break; // You cannot retry the call
        }
    }
    return NO;
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
                                                                     @"Name":               displayName,
                                                                     @"Privacy":            @"Private",
                                                                     @"SmugSearchable":     @"No",
                                                                     @"WorldSearchable":    @"No",
                                                                     }
                                                             verb: @"POST"];
    NSURLResponse *response;
    NSError *error;
    NSInteger retries = MMDefaultRetries;
    while (retries-- > 0)
    {
        NSData *serverData = [NSURLConnection sendSynchronousRequest: createAlbumRequest
                                                   returningResponse: &response
                                                               error: &error];
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (error)
        {
            DDLogError(@"System error: %@", error);
            continue;
        }
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
            DDLogError(@"response=%@", [_smugmugOauth extractErrorResponseData: serverData]);
            break; // You cannot retry the call
        }
        if (uri)
        {
            return [[uri componentsSeparatedByString: @"/"] lastObject];
        }
    }
    return nil;
}

/**
 * Returns the "urlName" value (one piece of the path) for a folder. If the +beneath+ parameter is nil
 * the result will be a top-level folder creation. If the +beneath+ value is present, then it will
 * be inserted as part of the path. When used, "+beneath+ should only contain embedded slashes,
 * no initial or terminal ones, for example: "abc/def".
 * If something really goes wrong, nil is returned.
 */
- (void) findOrCreateFolder: (NSString *) urlName
                    beneath: (NSString *) partialPath
                displayName: (NSString *) displayName
                description: (NSString *) description
         completionCallback: (void (^) (NSString *)) completionCallback
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
    while (retries-- > 0)
    {
        NSData *serverData = [NSURLConnection sendSynchronousRequest: createFolderRequest
                                                   returningResponse: &response
                                                               error: &error];
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (error)
        {
            DDLogError(@"System error: %@", error);
            continue; // You can retry, unlikey to succeed
        }
        NSDictionary *parsedServerResponse = [MMDataUtility parseJsonData: serverData];
        NSInteger httpStatus = [httpResponse statusCode];
        
        NSString *defaultFolderName = nil;
        if (httpStatus == 200)
        {
            defaultFolderName = [parsedServerResponse valueForKeyPath: @"Response.Folder.UrlName"];
        }
        if (httpStatus == 409) // Conflict, it exists
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
            defaultFolderName = (NSString *)object;
        }
        if (defaultFolderName)
        {
            // If it was found or created call the callback with it
            completionCallback(defaultFolderName);
            return;
        }
        DDLogError(@"Network error httpStatusCode=%ld", (long)httpStatus);
        DDLogError(@"response=%@", [_smugmugOauth extractErrorResponseData: serverData]);
        break; // You cannot retry the call
    }
    completionCallback(nil); // Signals you completed and failed.
}

@end
