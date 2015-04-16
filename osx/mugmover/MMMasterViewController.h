//
//  MMMasterViewController.h
//  mugmover
//
//  Created by Bob Fitterman on 4/3/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class MMPhoto;
@class MMPhotoLibrary;
@class MMLibraryEvent;
@class MMSmugmug;

@interface MMMasterViewController : NSViewController <NSTableViewDelegate>

@property (weak)    IBOutlet    NSButton *              checkAllButton;
@property (weak)    IBOutlet    NSTableView *           eventsTable;
@property (weak)    IBOutlet    NSButton *              interruptButton;
@property (weak)    IBOutlet    NSTableView *           photosTable;
@property (weak)    IBOutlet    NSButton *              skipProcessedImageCheckbox;
@property (weak)    IBOutlet    NSButton *              transmitButton;
@property (weak)    IBOutlet    NSButton *              uncheckAllButton;

@property (strong)              NSImage *               activeIcon;
@property (strong)              NSImage *               completedIcon;
@property (strong)              NSImage *               incompleteIcon;
@property (strong)              NSArray *               libraryEvents;
@property (assign)              NSInteger               outstandingRequests;
@property (strong)              NSArray *               photos;
@property (strong)              MMLibraryEvent *        selectedEvent;
@property (assign)              NSInteger               selectedRow;
@property (strong)              MMSmugmug *             serviceApi;
@property (assign)              BOOL                    transmitting;
@property (strong)              NSOperationQueue *      uploadOperationQueue;

- (void) uploadCompleted;

@end
