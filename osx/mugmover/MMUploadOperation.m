//
//  MMUploadOperation.m
//  mugmover
//
//  Created by Bob Fitterman on 4/8/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMDataUtility.h"
#import "MMFileUtility.h"
#import "MMLibraryEvent.h"
#import "MMWindowController.h"
#import "MMOauthAbstract.h"
#import "MMOauthSmugmug.h"
#import "MMPhoto.h"
#import "MMPhotoLibrary.h"
#import "MMPrefsManager.h"
#import "MMSmugmug.h"
#import "MMUploadOperation.h"
#import "MMUiUtility.h"

extern const NSInteger MMDefaultRetries;

@implementation MMUploadOperation

- (id) initWithEvent: (MMLibraryEvent *) event
                 row: (NSInteger) row
             service: (MMSmugmug *) service
            folderId: (NSString *) folderId
    windowController: (MMWindowController *) windowController
{
    self = [self init];
    if (self)
    {
        _folderId = folderId;
        _event = event;
        _row = row;
        _service = service;
        _windowController = windowController;
    }
    return self;
}    

- (void) main
{
    // Do the transfer
    [self transferPhotosForEvent: _event
                       toService: _service
                        folderId: _folderId];
    [[NSOperationQueue mainQueue] addOperationWithBlock: ^(void)
     {
         [_windowController.eventsTable reloadData];
         _folderId = nil;
     }
    ];

    // Check if the return from the above was interrupted. If so, clean up.
    NSOperationQueue *queue = [NSOperationQueue currentQueue];
    if ((queue.operationCount == 1) ||  // The end was reached
        [self isCancelled])             // The user clicked "stop" button
    {
        [[NSOperationQueue mainQueue] addOperationWithBlock: ^(void)
         {
             [_windowController uploadCompleted];
         }
         ];
    }
}

- (void) transferPhotosForEvent: (MMLibraryEvent *) event
                      toService: (MMSmugmug *) service
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
                              service.uniqueId,
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
                if (![service hasAlbumId: albumId])
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
        if (!albumId)
        {
            NSString *description = [NSString stringWithFormat: @"From event \"%@\", uploaded via Mugmover", name];
            // If the old AlbumID hasn't been stored or can't be found, create a new one
            albumId = [service createAlbumWithUrlName: [MMSmugmug sanitizeUuid: [event uuid]]
                                             inFolder: folderId
                                          displayName: name
                                          description: description];
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
            if (self.isCancelled)
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
                    [_windowController incrementProgressBy: 1.0];
                    continue;               // And then we skip the processing
                }
            }

            error = [photo processPhoto];
            if (error)
            {
                [service logError: error];
                NSLog(@"ERROR >> %@", error);
                continue;
            }
            NSImage *currentPhotoThumbnail = [photo getThumbnailImage];
            [event setActivePhotoThumbnail: currentPhotoThumbnail
                                 withStatus: MMEventStatusActive];
            [_windowController setActivePhotoThumbnail: currentPhotoThumbnail];
            [[NSOperationQueue mainQueue] addOperationWithBlock: ^(void)
             {
                 [_windowController.eventsTable reloadData];
             }
             ];

            __block NSString *smugmugImageId = nil;
            // This must be declared inside the loop because it references "photo"
            ServiceResponseHandler processSmugmugUpload = ^(NSDictionary *response)
            {
                if ([[response valueForKeyPath: @"stat"] isEqualToString: @"ok"])
                {
                    NSMutableDictionary *serviceDictionary = [[response objectForKey: @"Image"] mutableCopy];
                    [serviceDictionary setObject: @"smugmug" forKey: @"service"];
                    NSString *imageUri = [serviceDictionary valueForKeyPath: @"ImageUri"];
                    smugmugImageId = [[imageUri componentsSeparatedByString: @"/"] lastObject];
                    [photo attachServiceDictionary: serviceDictionary];
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

            NSURLRequest *uploadRequest = [service.smugmugOauth upload: pathToFileToUpload
                                                               albumId: albumId
                                                        replacementFor: replacementFor
                                                          withPriorMd5: [service md5ForPhotoId: replacementFor]
                                                                 title: [photo titleForUpload]
                                                               caption: photo.caption
                                                              keywords: photo.keywordList
                                                                 error: &error];
            if (error)
            {
                [service logError: error];
                continue;
            }
            if (!uploadRequest)
            {
                // No uploadRequest and no error indicates we have been asked to
                // replace a file that already has been updated.
                
                // TODO We need to still update the object on Mugmover
                smugmugImageId = replacementFor;
            }
            else
            {
                // 1. Upload to Smugmug
                error = [service.smugmugOauth synchronousUrlRequest: uploadRequest
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
                    [service logError: error];
                    DDLogError(@"Upload to Smugmug server failed for photo %@.", photo);
                    continue;
                }

                // 2. Upload the data to Mugmover
                error = [photo sendPhotoToMugmover];
                if (error)
                {
                    [service logError: error];
                    DDLogError(@"Upload to MM server failed for photo %@, error %@.", photo, error);
                    // TODO Kill the uploaded photo that was just uploaded first
                    continue;
                }
            }
            // 4. Now we mark it as sent in our local store
            if (smugmugImageId)
            {
                // We do it on each pass in case it bombs on a large collection of photos
                [albumState setValue: smugmugImageId forKey: mappingKeyPath];
                [defaults setObject: albumState forKey: albumKey];
                [defaults synchronize];
                completedTransfers++;
                [_windowController incrementProgressBy: 1.0];
            }
        }
        finalStatus = (completedTransfers == [photos count]) ? MMEventStatusCompleted : MMEventStatusIncomplete;

        // And at the end we have to do it in case some change(s) did not get stored
        [defaults setObject: albumState forKey: albumKey];
        [defaults synchronize];

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
                NSURLRequest *eventRequest = [service.smugmugOauth apiRequest: apiCall
                                                                   parameters: @{@"HighlightAlbumImageUri": featuredImageUri}
                                                                          verb: @"PATCH"];
                error = [service.smugmugOauth synchronousUrlRequest: eventRequest
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
        // Restore the display to the default image for this album
        [event setActivePhotoThumbnail: nil withStatus: finalStatus];
        [[NSOperationQueue mainQueue] addOperationWithBlock: ^(void)
         {
             [_windowController.eventsTable reloadData];
        }];
    }
}
@end
