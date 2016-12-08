//
//  MMDestinationFileSystem.m
//  mugmover
//
//  Created by Bob Fitterman on 12/7/16.
//  Copyright © 2016 Dicentra LLC. All rights reserved.
//

#import "MMDestinationAbstract.h"
#import "MMDestinationFileSystem.h"
#import "MMLibraryEvent.h"
#import "MMPhoto.h"
#import "MMPrefsManager.h"
#import "MMWindowController.h"
#import "MMUploadOperation.h"

@implementation MMDestinationFileSystem

- (id) initFromDictionary: (NSDictionary *) dictionary
{
    self = [super init];
    if ((self) &&
        (dictionary && [[dictionary valueForKey: @"type"] isEqualToString: @"filesystem"]))
    {
        self.uniqueId = [dictionary valueForKey: @"id"];
    }
    return self;
}

/**
 * This method returns an NSString pointer if it succeeds. The caller never uses the value (in the
 * instance of this service. Hence the arbitrary return value to indicate success.
 * It looks for a folder, creates it if it doesn't exist. The folder should contain also have a 
 * hidden file called ".mugmover" which will help track the mapping of iPhoto events to 
 * file system folders.
 */
- (NSString *) findOrCreateFolderForLibrary: (MMPhotoLibrary *) library
{
    NSString *path = [self.uniqueId stringByExpandingTildeInPath];
    NSURL *pathUrl = [NSURL fileURLWithPath: path
                                isDirectory: YES];
    NSError *error = nil;

    if (![[NSFileManager defaultManager] fileExistsAtPath: path])
    {
        [[NSFileManager defaultManager] createDirectoryAtURL: pathUrl
                                 withIntermediateDirectories: YES
                                                  attributes: nil
                                                       error: &error];
        if (error)
        {
            return nil; /* Something went wrong with the create */
        }
    }
    // Look for the hidden file and attempt to deserialize it
    NSURL *hiddenFileUrl = [pathUrl URLByAppendingPathComponent: @".mugmover"];
    
    // Sloppy, but it's local so let's go synchronous

    NSURLRequest *request = [[NSURLRequest alloc] initWithURL: hiddenFileUrl];
    NSData *fileContents = [NSURLConnection sendSynchronousRequest: request
                                                 returningResponse: nil
                                                             error: &error];
    if (error)
    {
        if (error.code == -1100) // File not found
        {
            _eventDictionary = @{};
        }
        else
        {
            // TODO Report the error, then return
            return nil;
        }
    }
    else
    {
        _eventDictionary = [NSJSONSerialization JSONObjectWithData: fileContents
                                                           options: 0
                                                             error: &error];
        if (error)
        {
            // TODO Report corrupted JSON file, then start clean.
            _eventDictionary = @{};
        }
    }
    return @"I'm happy"; // Any string value would do.
}

- (NSString *) identifier
{
    return @"filesystem";
}

- (NSString *) name
{
    return [NSString stringWithFormat: @"%@ (File System)\n%@", @"_handle", self.uniqueId];
}

- (NSString *) oauthAccessToken
{
    return @"";
}

- (NSString *) oauthTokenSecret
{
    return @"";
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
/*
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
*/
        // If the albumId is present and not found or this is a new (to us) album,
        // go ahead and create one.
/*
        BOOL albumCreatedOnThisPass = NO;
        if (!albumId)
        {
            NSString *description = [NSString stringWithFormat: @"From event \"%@\", uploaded via Mugmover", name];
            // If the old AlbumID hasn't been stored or can't be found, create a new one
            albumId = [self createAlbumWithUrlName: [MMDestinationFileSystem sanitizeUuid: [event uuid]]
                                          inFolder: folderId
                                       displayName: name
                                       description: description];
            albumCreatedOnThisPass = (albumId != nil);
            [albumState setValue: albumId forKey: @"albumId"];
            NSMutableDictionary *mappingDictionary = [[NSMutableDictionary alloc] initWithCapacity: [photos count]];
            [albumState setValue: mappingDictionary forKey: @"mapping"];
        }
        
        // We use these next two to keep track of whether everything completes
*/
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
/*
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
                NSString *jpegPath = [MMFileUtility temporaryJpegFromPath: photo.iPhotoOriginalImagePath];
                if (!jpegPath)
                {
                    DDLogError(@"Failed to create JPEG to %@ (at %@)", photo, photo.iPhotoOriginalImagePath);
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
 */
        }
        finalStatus = (completedTransfers == [photos count]) ? MMEventStatusCompleted : MMEventStatusIncomplete;

        // And at the end we have to do it in case some change(s) did not get stored
        [defaults setObject: albumState forKey: albumKey];
        [MMPrefsManager syncIfNecessary: defaults];
/*        
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
 */
    }
}

@end
