//
//  MMUploadOperation.h
//  mugmover
//
//  Created by Bob Fitterman on 4/8/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MMLibraryEvent;
@class MMWindowController;
@class MMPhotoLibrary;
@class MMSmugmug;

@interface MMUploadOperation : NSOperation

@property (strong, readonly)    NSString *                  folderId;
@property (weak, readonly)      MMLibraryEvent *            event;
@property (assign)              NSInteger                   row;
@property (weak, readonly)      MMSmugmug *                 service;
@property (weak)                MMWindowController *        windowController;

- (id) initWithEvent: (MMLibraryEvent *) event
                 row: (NSInteger) row
             service: (MMSmugmug *) service
            folderId: (NSString *) folderId
    windowController: (MMWindowController *) windowController;

@end
