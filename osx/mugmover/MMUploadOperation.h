//
//  MMUploadOperation.h
//  mugmover
//
//  Created by Bob Fitterman on 4/8/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MMLibraryEvent;
@class MMMasterViewController;
@class MMPhotoLibrary;
@class MMSmugmug;

@interface MMUploadOperation : NSOperation

@property (weak, readonly)      MMLibraryEvent *            event;
@property (weak, readonly)      MMPhotoLibrary *            library;
@property (assign)              NSInteger                   row;
@property (weak, readonly)      MMSmugmug *                 service;
@property (weak)                MMMasterViewController *    viewController;

- (id) initWithEvent: (MMLibraryEvent *) event
                from: (MMPhotoLibrary *) library
                 row: (NSInteger) row
             service: (MMSmugmug *) service
      viewController: (MMMasterViewController *) viewController;

@end
