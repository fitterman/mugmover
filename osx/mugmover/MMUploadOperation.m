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
    [_service transferPhotosForEvent: _event
                     uploadOperation: self
                    windowController: _windowController
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

@end
