//
//  MMUploadOperation.m
//  mugmover
//
//  Created by Bob Fitterman on 4/8/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMUploadOperation.h"
#import "MMPhoto.h"
#import "MMLibraryEvent.h"
#import "MMMasterViewController.h"
#import "MMSmugmug.h"
#import "MMOauthAbstract.h"
#import "MMOauthSmugmug.h"

extern const NSInteger MMDefaultRetries;

@implementation MMUploadOperation

- (id) initWithPhotos: (NSArray *) photos
             forEvent: (MMLibraryEvent *) event
              service: (MMSmugmug *) service
       viewController: (MMMasterViewController *) viewController
{
    self = [self init];
    if (self)
    {
        _photos = photos;
        _event = event;
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
        NSString *newAlbumUri = [_service findOrCreateAlbum: [MMSmugmug sanitizeUuid: [_event uuid]]
                                                    beneath: _service.defaultFolder
                                                displayName: name
                                                description: description];
        for (MMPhoto *photo in _photos)
        {
            [photo processPhoto];
            // This must be declared inside the loop because it references "photo"
            ServiceResponseHandler processSmugmugUpload = ^(NSDictionary *response)
            {
                if ([[response valueForKeyPath: @"stat"] isEqualToString: @"ok"])
                {
                    NSMutableDictionary *serviceDictionary = [[response objectForKey: @"Image"] mutableCopy];
                    [serviceDictionary setObject: @"smugmug" forKey: @"service"];
                    [photo attachServiceDictionary: serviceDictionary];
                }
                NSLog(@"response=%@", response);
            };
            NSURLRequest *uploadRequest = [_service.smugmugOauth upload: photo.iPhotoOriginalImagePath
                                                               albumUri: newAlbumUri
                                                                  title: @"photo title"
                                                                caption: @"photo caption"
                                                                   tags: @[@"foo", @"bar"]];
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
            }
            uploadRequest = nil;
            if ((!status) || self.isCancelled)
            {
                break;
            }
        }
    }
    [[NSOperationQueue mainQueue] addOperationWithBlock: ^(void)
        {
            [_viewController uploadCompletedWithStatus: status];
        }
     ];
}
@end
