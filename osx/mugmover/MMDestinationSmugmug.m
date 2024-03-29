//
//  MMDestinationSmugmug.m
//  Everything to do with Smugmug integration.
//
//  Created by Bob Fitterman on 03/17/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMDestinationAbstract.h"
#import "MMDestinationSmugmug.h"
#import "MMLibraryEvent.h"
#import "MMPhoto.h"
#import "MMPhotoLibrary.h"
#import "MMPrefsManager.h"
#import "MMOauthSmugmug.h"
#import "MMDataUtility.h"
#import "MMFileUtility.h"
#import "MMUploadOperation.h"
#import "MMWindowController.h"

@implementation MMDestinationSmugmug

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
    if ((self) &&
        (dictionary && [[dictionary valueForKey: @"type"] isEqualToString: @"smugmug"]))
    {
        self.uniqueId = [dictionary valueForKey: @"id"];
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

#pragma mark == Public Methods ==

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

- (void) close
{
    _handle = nil;
    [super close];
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
                           self.uniqueId,
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

- (NSString *) identifier
{
    return @"smugmug";
}

- (NSString *) name
{
    return [NSString stringWithFormat: @"%@ (Smugmug)\n%@", _handle, self.uniqueId];
}

- (NSString *) oauthAccessToken
{
    return [_smugmugOauth accessToken];
}

- (NSString *) oauthTokenSecret
{
    return [_smugmugOauth tokenSecret];
}

- (NSDictionary *) serialize
{
    return @{@"type":   [self identifier],
             @"id":     self.uniqueId,
             @"name":   (!_handle ? @"(none)" : _handle)};
}

/**
 * Tightly connected to the MMUploadOperation class. This is what does the
 * actual transfer.
 */
- (void) transferPhotosForEvent: (MMLibraryEvent *) event
                uploadOperation: (MMUploadOperation *) uploadOperation
               windowController: (MMWindowController *) windowController
                       folderId: (NSString *) folderId
{
    @autoreleasepool
    {
        NSString *name = [event name];
        if ((!name) || ([name length] == 0))
        {
            name = [event dateRange];
        }
        
        // Restore the preferences (defaults)
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        BOOL reprocessAllImagesPreviouslyTransmitted = [MMPrefsManager
                                                        boolForKey: @"reprocessAllImagesPreviouslyTransmitted"];
        NSString *albumKey = [NSString stringWithFormat: @"smugmug.%@.albums.%@",
                              self.uniqueId,
                              [event uuid]];
        NSArray *photos = [MMPhoto getPhotosForEvent: event];
        
        // Get the preferences (defaults) for this event within this service
        NSMutableDictionary *albumState = [[defaults objectForKey: albumKey] mutableCopy];
        NSString *albumId = nil;
        
        if (albumState)
        {
            albumId = [albumState objectForKey: @"albumId"];
            if (albumId)
            {
                // If you can't find the album, clear the "albumId" so a new one will be created
                if (![self hasAlbumId: albumId])
                {
                    albumId = nil;
                }
            }
        }
        else // albumState has never been saved, initialize it...
        {
            albumState = [[NSMutableDictionary alloc] init];
        }
        
        // If the albumId is present and not found or this is a new (to us) album,
        // go ahead and create one.
        BOOL albumCreatedOnThisPass = NO;
        if (!albumId)
        {
            NSString *description = [NSString stringWithFormat: @"From event \"%@\", uploaded via Mugmover", name];
            // If the old AlbumID hasn't been stored or can't be found, create a new one
            albumId = [self createAlbumWithUrlName: [MMDestinationSmugmug sanitizeUuid: [event uuid]]
                                          inFolder: folderId
                                       displayName: name
                                       description: description];
            albumCreatedOnThisPass = (albumId != nil);
            [albumState setValue: albumId forKey: @"albumId"];
            NSMutableDictionary *mappingDictionary = [[NSMutableDictionary alloc] initWithCapacity: [photos count]];
            [albumState setValue: mappingDictionary forKey: @"mapping"];
        }
        
        // We use these next two to keep track of whether everything completes
        NSInteger completedTransfers = 0;
        MMEventStatus finalStatus = MMEventStatusIncomplete; // Assume something goes wrong
        
        NSError *error;
        
        for (MMPhoto *photo in photos)
        {
            error = nil;
            
            // Before processing the next photo, see if we've been asked to abort
            if (uploadOperation.isCancelled)
            {
                break;
            }
            
            // The +mappingKeyPath+ points to the Smugmug photo ID associated with this photo the
            // last time it was uploaded (if ever). This information can be used to facilitate the
            // replacement of the image. For now, it's just a way to know not to repeat an upload.
            NSString *mappingKeyPath = [NSString stringWithFormat: @"mapping.%@", photo.versionUuid];
            NSString *replacementFor = nil;
            if (mappingKeyPath)
            {
                replacementFor = [albumState valueForKeyPath: mappingKeyPath];
                // If it's already marked as uploaded and we aren't reprocessing, skip it...
                if (replacementFor && !reprocessAllImagesPreviouslyTransmitted)
                {
                    completedTransfers++;   // We consider it sent already so we can get the icons right
                    [windowController incrementProgressBy: 1.0];
                    continue;               // And then we skip the processing
                }
            }
            
            error = [photo processPhoto];
            if (error)
            {
                [self logError: error];
                NSLog(@"ERROR >> %@", error);
                continue;
            }
            NSImage *currentPhotoThumbnail = [photo getThumbnailImage];
            [event setActivePhotoThumbnail: currentPhotoThumbnail
                                withStatus: MMEventStatusActive];
            [windowController setActivePhotoThumbnail: currentPhotoThumbnail];
            [[NSOperationQueue mainQueue] addOperationWithBlock: ^(void)
             {
                 [windowController.eventsTable reloadData];
             }
             ];
            
            __block NSString *smugmugImageId = nil;
            // This must be declared inside the loop because it references "photo"
            ServiceResponseHandler processSmugmugUpload = ^(NSDictionary *response)
            {
                if ([[response valueForKeyPath: @"stat"] isEqualToString: @"ok"])
                {
                    NSMutableDictionary *serviceDictionary = [[NSMutableDictionary alloc] init];
                    [serviceDictionary setObject: @"smugmug"
                                          forKey: @"name"];
                    [serviceDictionary setObject: [response valueForKeyPath: @"Image.URL"]
                                          forKey: @"url"];
                    [serviceDictionary setObject: _handle
                                          forKey: @"handle"];
                    [photo attachServiceDictionary: serviceDictionary];
                    
                    NSString *imageUri = [response valueForKeyPath: @"Image.ImageUri"];
                    NSArray *pieces = [[imageUri lastPathComponent] componentsSeparatedByString: @"-"];
                    smugmugImageId = pieces[0];
                }
                else // In theory, you will no longer get here because we check for errors
                {
                    DDLogError(@"response=%@", response);
                }
            };
            
            NSString *pathToFileToUpload = photo.iPhotoOriginalImagePath;
            BOOL imageRequiresConversion = [photo isFormatRequiringConversion];
            if (imageRequiresConversion)
            {
                NSString *jpegPath = [MMFileUtility jpegFromPath: photo.iPhotoOriginalImagePath
                                                     toDirectory: [MMFileUtility pathToTemporaryDirectory]];
                if (!jpegPath)
                {
                    DDLogError(@"Failed to create JPEG to %@ (from %@)", photo, photo.iPhotoOriginalImagePath);
                    break;
                }
                pathToFileToUpload = jpegPath;
            }
            
            NSURLRequest *uploadRequest = [_smugmugOauth upload: pathToFileToUpload
                                                        albumId: albumId
                                                 replacementFor: replacementFor
                                                   withPriorMd5: [self md5ForPhotoId: replacementFor]
                                                          title: [photo titleForUpload]
                                                        caption: photo.caption
                                                       keywords: photo.keywordList
                                                          error: &error];
            if (error)
            {
                [self logError: error];
                continue;
            }
            if (!uploadRequest)
            {
                // No uploadRequest and no error indicates we have been asked to
                // replace a file that already has been updated.
                
                // TODO We need to still update the object on Mugmarker, being care to update
                //      not create nor to fully replace the object (as you could have data collisions).
                smugmugImageId = replacementFor;
            }
            else
            {
                // 1. Upload to Smugmug
                error = [_smugmugOauth synchronousUrlRequest: uploadRequest
                                                       photo: photo
                                           remainingAttempts: MMDefaultRetries
                                           completionHandler: processSmugmugUpload];
                if (imageRequiresConversion) // There's some cleanup to do before checking for an error
                {
                    // Delete the temp directory
                    [[NSFileManager defaultManager] removeItemAtPath: pathToFileToUpload
                                                               error: nil];
                }
                if (error)
                {
                    [self logError: error];
                    DDLogError(@"Upload to Smugmug server failed for photo %@.", photo);
                    continue;
                }
                
                // 2. Get the image sizes and update to the photo object
                NSDictionary *sizes = [self imageSizesForPhotoId: smugmugImageId];
                [photo setUrlsForLargeImage: [sizes valueForKeyPath: @"ImageSizeLarge.Url"]
                              originalImage: [sizes valueForKeyPath: @"ImageSizeOriginal.Url"]];
                
                // 3. Upload the data to Mugmarker
                error = [photo sendPhotoToMugmover];
                if (error)
                {
                    [self logError: error];
                    DDLogError(@"Upload to MM server failed for photo %@, error %@.", photo, error);
                    
                    // Because this was a new image (not a replacement to Smugmug),
                    // we attempt to delete the photo from the service so it's not
                    // on the service and missing from Mugmarker.
                    if (![self deletePhotoId: smugmugImageId])
                    {
                        DDLogError(@"Cleanup deletion failed for photo %@", smugmugImageId);
                    }
                    else
                    {
                        smugmugImageId = nil; // So we think it failed (because it did)
                    }
                    continue;
                }
            }
            // 4. Now we mark it as sent in our local store
            if (smugmugImageId)
            {
                // We do it on each pass in case it bombs on a large collection of photos
                [albumState setValue: smugmugImageId forKey: mappingKeyPath];
                [defaults setObject: albumState forKey: albumKey];
                [MMPrefsManager syncIfNecessary: defaults];
                completedTransfers++;
                [windowController incrementProgressBy: 1.0];
            }
        }
        finalStatus = (completedTransfers == [photos count]) ? MMEventStatusCompleted : MMEventStatusIncomplete;
        
        // And at the end we have to do it in case some change(s) did not get stored
        [defaults setObject: albumState forKey: albumKey];
        [MMPrefsManager syncIfNecessary: defaults];
        
        // If we were unable to do any transfers AND this is a newly-created album, we need to
        // delete the album as there is no record of its existence preserved and it will just hang
        // out in an unusable state.
        if (albumCreatedOnThisPass && (completedTransfers == 0))
        {
            if (![self deleteAlbumId: albumId])
            {
                DDLogError(@"Cleanup deletion failed for album %@", albumId);
            }
        }
        else
        {
            // Now we update the featured photo for the album
            NSString *featuredPhotoUuid = [event featuredImageUuid];
            NSString *featuredPhotoMappingPath = [NSString stringWithFormat: @"mapping.%@", featuredPhotoUuid];
            if (featuredPhotoUuid && featuredPhotoMappingPath)
            {
                NSString *featuredPhotoId = [albumState valueForKeyPath: featuredPhotoMappingPath];
                if (featuredPhotoId)
                {
                    NSString *featuredImageUri = [NSString stringWithFormat: @"/api/v2/album/%@/image/%@",
                                                  albumId,
                                                  featuredPhotoId];
                    NSString *apiCall = [NSString stringWithFormat: @"album/%@", albumId];
                    NSURLRequest *eventRequest = [_smugmugOauth apiRequest: apiCall
                                                                parameters: @{@"HighlightAlbumImageUri": featuredImageUri}
                                                                      verb: @"PATCH"];
                    error = [_smugmugOauth synchronousUrlRequest: eventRequest
                                                           photo: nil
                                               remainingAttempts: MMDefaultRetries
                                               completionHandler: nil];
                    if (error)
                    {
                        // TODO Log this error!
                        DDLogWarn(@"Unable to set featured image for event album (%@).", event.name);
                    }
                }
            }
        }
        // Restore the display to the default image for this album
        [event setActivePhotoThumbnail: nil withStatus: finalStatus];
        [[NSOperationQueue mainQueue] addOperationWithBlock: ^(void)
         {
             [windowController.eventsTable reloadData];
         }];
    }
}

#pragma mark == Private Methods ==

/**
 This either reconsitutes an Oauth token from the stored preferences (NSUserDefaults) or
 triggers a new Oauth dance. You know the outcome by observing "initializationProgress".
 */
- (void) configureOauthRetryOnFailure: (BOOL) attemptRetry
{
    if (self.uniqueId)
    {
        NSArray *tokenAndSecret = [MMPrefsManager tokenAndSecretForDestination: @"smugmug"
                                                                      uniqueId: self.uniqueId];
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
            [MMPrefsManager clearTokenAndSecretForDestination: @"smugmug"
                                                     uniqueId: self.uniqueId];
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
        self.uniqueId = [parsedServerResponse valueForKeyPath: @"Response.User.RefTag"];
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

@end
