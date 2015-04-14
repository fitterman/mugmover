//
//  MMUploadOperation.m
//  mugmover
//
//  Created by Bob Fitterman on 4/8/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMUploadOperation.h"
#import "MMPhoto.h"
#import "MMPhotoLibrary.h"
#import "MMLibraryEvent.h"
#import "MMMasterViewController.h"
#import "MMSmugmug.h"
#import "MMOauthAbstract.h"
#import "MMOauthSmugmug.h"

extern const NSInteger MMDefaultRetries;

@implementation MMUploadOperation

- (id) initWithEvent: (MMLibraryEvent *) event
                 row: (NSInteger) row
             service: (MMSmugmug *) service
      viewController: (MMMasterViewController *) viewController
{
    self = [self init];
    if (self)
    {
        _event = event;
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
            // The +mappingKeyPath+ points to the Smugmug photo ID associated with this photo the
            // last time it was uploaded (if ever). This information can be used to facilitate the
            // replacement of the image. For now, it's just a way to know not to repeat an upload.
            NSString *mappingKeyPath = [NSString stringWithFormat: @"mapping.%@", photo.versionUuid];
            if (mappingKeyPath && [albumState valueForKeyPath: mappingKeyPath])
            {
                completedTransfers++;   // We consider it sent already so we can get the icons right
                continue;               // And then we skip the processing
            }
            [photo processPhoto];
            [_event setActivePhoto: photo
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
            NSURLRequest *uploadRequest = [_service.smugmugOauth upload: photo.iPhotoOriginalImagePath
                                                                albumId: newAlbumId
                                                                  title: @"photo title"
                                                                caption: @"photo caption"
                                                                   tags: photo.keywordList];
            status = [_service.smugmugOauth synchronousUrlRequest: uploadRequest
                                                remainingAttempts: MMDefaultRetries
                                                completionHandler: processSmugmugUpload];
            if (!status)
            {
                DDLogError(@"Upload to Smugmug server failed for photo %@.", photo);
            }
            else
            {
                status = [photo sendPhotoToMugmover];
                if (!status)
                {
                    DDLogError(@"Upload to MM server failed for photo %@.", photo);
                }
                else
                {
                    if (smugmugImageId)
                    {
                        // We do it on each pass in case it bombs on a large collection of photos
                        [albumState setValue: smugmugImageId forKey: mappingKeyPath];
                        [defaults setObject: albumState forKey: albumKey];
                        [defaults synchronize];
                        completedTransfers++;
                    }
                }
            }
            uploadRequest = nil;
            if (self.isCancelled)
            {
                break;
            }
        }
        if (completedTransfers == [photos count])
        {
            finalStatus = MMEventStatusCompleted;
        }

        // And at the end we have to do it in case some change did not get stored
        [defaults setObject: albumState forKey: albumKey];
        [defaults synchronize];

        [_event setActivePhoto: nil withStatus: finalStatus];
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
