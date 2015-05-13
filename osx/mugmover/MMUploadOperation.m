//
//  MMUploadOperation.m
//  mugmover
//
//  Created by Bob Fitterman on 4/8/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMFileUtility.h"
#import "MMLibraryEvent.h"
#import "MMMasterViewController.h"
#import "MMOauthAbstract.h"
#import "MMOauthSmugmug.h"
#import "MMPhoto.h"
#import "MMPhotoLibrary.h"
#import "MMSmugmug.h"
#import "MMUploadOperation.h"

extern const NSInteger MMDefaultRetries;

@implementation MMUploadOperation

- (id) initWithEvent: (MMLibraryEvent *) event
                 row: (NSInteger) row
             service: (MMSmugmug *) service
            folderId: (NSString *) folderId
             options: (NSDictionary *) options
      viewController: (MMMasterViewController *) viewController
{
    self = [self init];
    if (self)
    {
        _folderId = folderId;
        _event = event;
        _skipProcessedImages = [[options valueForKeyPath: @"skipProcessedImages"] boolValue];
        _row = row;
        _service = service;
        _viewController = viewController;
    }
    return self;
}    

- (void) main
{
    // Do the transfer
    [self transferPhotosForEvent: _event
                       toService: _service
                        folderId: _folderId
             skipProcessedImages: _skipProcessedImages];
    [[NSOperationQueue mainQueue] addOperationWithBlock: ^(void)
     {
         [_viewController.eventsTable reloadData];
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
             [_viewController uploadCompleted];
         }
         ];
    }
}

- (void) transferPhotosForEvent: (MMLibraryEvent *) event
                      toService: (MMSmugmug *) service
                       folderId: (NSString *) folderId
            skipProcessedImages: (BOOL) skipProcessedImages
{
    @autoreleasepool
    {
        NSString *name = [event name];
        if ((!name) || ([name length] == 0))
        {
            name = [event dateRange];
        }

        NSString *description = [NSString stringWithFormat: @"From event \"%@\", uploaded via Mugmover", name];
        NSString *newAlbumId = [service findOrCreateAlbum: [MMSmugmug sanitizeUuid: [event uuid]]
                                                 inFolder: folderId
                                              displayName: name
                                              description: description];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *albumKey = [NSString stringWithFormat: @"smugmug.%@.albums.%@",
                              service.uniqueId,
                              [event uuid]];
        NSArray *photos = [MMPhoto getPhotosForEvent: event];
        NSMutableDictionary *albumState = [[defaults objectForKey: albumKey] mutableCopy];
        if (!albumState)
        {
            albumState = [[NSMutableDictionary alloc] init];
            [albumState setValue: newAlbumId forKey: @"albumId"];
            NSMutableDictionary *mappingDictionary = [[NSMutableDictionary alloc] initWithCapacity: [photos count]];
            [albumState setValue: mappingDictionary forKey: @"mapping"];
        }

        // We use these next two to keep track of whether everything completes
        NSInteger completedTransfers = 0;
        MMEventStatus finalStatus = MMEventStatusIncomplete; // Assume something goes wrong

        for (MMPhoto *photo in photos)
        {
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
                if (replacementFor && skipProcessedImages)
                {
                    completedTransfers++;   // We consider it sent already so we can get the icons right
                    [_viewController incrementProgressBy: 1.0];
                    continue;               // And then we skip the processing
                }
            }

            [photo processPhoto];
            [event setActivePhotoThumbnail: [photo getThumbnailImage]
                                 withStatus: MMEventStatusActive];
            [[NSOperationQueue mainQueue] addOperationWithBlock: ^(void)
             {
                 [_viewController.eventsTable reloadData];
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
                NSLog(@"response=%@", response);
            };

            NSString *pathToFileToUpload = photo.iPhotoOriginalImagePath;
            BOOL tiff = [photo isTiff];
            if (tiff)
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
                                                               albumId: newAlbumId
                                                        replacementFor: replacementFor
                                                                 title: [photo titleForUpload]
                                                               caption: photo.caption
                                                              keywords: photo.keywordList];
            // 1. Upload to Smugmug
            BOOL status = [service.smugmugOauth synchronousUrlRequest: uploadRequest
                                                    remainingAttempts: MMDefaultRetries
                                                    completionHandler: processSmugmugUpload];
            if (tiff)
            {
                // Delete the temp directory
                [[NSFileManager defaultManager] removeItemAtPath: pathToFileToUpload
                                                           error:nil];
            }
            if (!status)
            {
                DDLogError(@"Upload to Smugmug server failed for photo %@.", photo);
                break;
            }

            // 2. Upload the data to Mugmover
            status = [photo sendPhotoToMugmover];
            if (!status)
            {
                DDLogError(@"Upload to MM server failed for photo %@.", photo);
                // TODO Kill the uploaded photo first
                break;
            }

            // 4. Now we mark it as sent in our local store
            if (smugmugImageId)
            {
                // We do it on each pass in case it bombs on a large collection of photos
                [albumState setValue: smugmugImageId forKey: mappingKeyPath];
                [defaults setObject: albumState forKey: albumKey];
                [defaults synchronize];
                completedTransfers++;
                [_viewController incrementProgressBy: 1.0];
            }
        }
        if (completedTransfers == [photos count])
        {
            finalStatus = MMEventStatusCompleted;
        }

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
                                              newAlbumId,
                                              featuredPhotoId];
                NSString *apiCall = [NSString stringWithFormat: @"album/%@", newAlbumId];
                NSURLRequest *eventRequest = [service.smugmugOauth apiRequest: apiCall
                                                                   parameters: @{@"HighlightAlbumImageUri": featuredImageUri}
                                                                          verb: @"PATCH"];
                BOOL status = [service.smugmugOauth synchronousUrlRequest: eventRequest
                                                        remainingAttempts: MMDefaultRetries
                                                        completionHandler: nil];
                if (!status)
                {
                    DDLogWarn(@"Unable to set featured image for event album (%@).", event.name);
                }
            }
        }

        // Restore the display to the default image for this album
        [event setActivePhotoThumbnail: nil withStatus: finalStatus];

    }
}
@end
