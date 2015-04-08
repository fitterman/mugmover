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
@class MMSmugmug;

@interface MMUploadOperation : NSOperation

@property (weak, readonly)      MMLibraryEvent *            event;
@property (weak, readonly)      NSArray *                   photos;
@property (weak, readonly)      MMSmugmug *                 service;
@property (weak)                MMMasterViewController *    viewController;

- (id) initWithPhotos: (NSArray *) photos
             forEvent: (MMLibraryEvent *) event
              service: (MMSmugmug *) service
       viewController: (MMMasterViewController *) viewController;

@end
