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
             options: (NSDictionary *) options
      viewController: (MMMasterViewController *) viewController
{
    self = [self init];
    if (self)
    {
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
    BOOL status = NO;

    @autoreleasepool
    {
        NSString *name = [_event name];
        if ((!name) || ([name length] == 0))
        {
            name = [_event dateRange];
        }
        NSString *description = [NSString stringWithFormat: @"From event \"%@\", uploaded via Mugmover", name];
        NSString *newAlbumId = [_service findOrCreateAlbum: [MMSmugmug sanitizeUuid: [_event uuid]]
                                                   beneath: _service.defaultFolder
                                               displayName: name
                                               description: description];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *albumKey = [NSString stringWithFormat: @"smugmug.%@.albums.%@",
                                                          _service.currentAccountHandle,
                                                          [_event uuid]];
        NSArray *photos = [MMPhoto getPhotosForEvent: _event];
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
                if (replacementFor && _skipProcessedImages)
                {
                    completedTransfers++;   // We consider it sent already so we can get the icons right
                    [_viewController.progressIndicator incrementBy: 1.0];
                    continue;               // And then we skip the processing
                }
            }

            [photo processPhoto];
            [_event setActivePhotoThumbnail: photo.iPhotoOriginalImagePath
                                 withStatus: MMEventStatusActive];
            [[NSOperationQueue mainQueue] addOperationWithBlock: ^(void)
               {
                   [_viewController.eventsTable reloadData]; // TODO Optimize to single cell
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

            NSURLRequest *uploadRequest = [_service.smugmugOauth upload: pathToFileToUpload
                                                                albumId: newAlbumId
                                                         replacementFor: replacementFor
                                                                  title: [photo titleForUpload]
                                                                caption: photo.caption
                                                               keywords: photo.keywordList];
            // 1. Upload to Smugmug
            status = [_service.smugmugOauth synchronousUrlRequest: uploadRequest
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
                [_viewController.progressIndicator incrementBy: 1.0];
            }
        }
        if (completedTransfers == [photos count])
        {
            finalStatus = MMEventStatusCompleted;
        }

        // And at the end we have to do it in case some change did not get stored
        [defaults setObject: albumState forKey: albumKey];
        [defaults synchronize];

        [_event setActivePhotoThumbnail: nil withStatus: finalStatus];
        [[NSOperationQueue mainQueue] addOperationWithBlock: ^(void)
         {
             [_viewController.eventsTable reloadData]; // TODO Optimize to single cell
         }
         ];
    }
    NSOperationQueue *queue = [NSOperationQueue currentQueue];
    if ((queue.operationCount == 1) ||  // The end was reached
        [self isCancelled])             // The user clicked "interrupt" button
    {
        [[NSOperationQueue mainQueue] addOperationWithBlock: ^(void)
         {
             [_viewController uploadCompleted];
         }
         ];
    }
}
@end
