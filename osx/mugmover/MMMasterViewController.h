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
@class MMPhotoLibraryManager;
@class MMProgressWindowController;
@class MMServiceManager;

@interface MMMasterViewController : NSViewController <NSTableViewDelegate, NSSplitViewDelegate>


@property (weak)    IBOutlet    NSSegmentedCell *       addLibraryButton;
@property (weak)    IBOutlet    NSButton *              checkAllButton;
@property (weak)    IBOutlet    NSTableView *           eventsTable;
@property (weak)    IBOutlet    NSScrollView *          librariesScrollView;
@property (weak)    IBOutlet    NSSegmentedControl *    librariesSegmentedControl;
@property (weak)    IBOutlet    NSTableView *           librariesTable;
@property (weak)    IBOutlet    NSTableView *           photosTable;
@property (weak)    IBOutlet    NSScrollView *          servicesScrollView;
@property (weak)    IBOutlet    NSSegmentedControl *    servicesSegmentedControl;
@property (weak)    IBOutlet    NSTableView *           servicesTable;
@property (weak)    IBOutlet    NSButton *              skipProcessedImageCheckbox;
@property (weak)    IBOutlet    NSSplitView *           splitView;
@property (weak)    IBOutlet    NSButton *              transmitButton;
@property (weak)    IBOutlet    NSButton *              uncheckAllButton;

@property (strong)              NSImage *                       activeIcon;
@property (strong)              NSImage *                       completedIcon;
@property (strong)              NSImage *                       incompleteIcon;
@property (strong)              MMPhotoLibrary *                library;
@property (strong)              NSImage *                       libraryIcon;
@property (strong)              MMPhotoLibraryManager *         libraryManager;
@property (strong)              MMProgressWindowController *    progressWindowController;
@property (assign)              NSInteger                       outstandingRequests;
@property (strong)              NSArray *                       photos;
@property (strong)              MMLibraryEvent *                selectedEvent;
@property (strong)              NSImage *                       serviceIcon;
@property (strong)              MMServiceManager *              serviceManager;
@property (assign)              NSInteger                       totalImagesToTransmit;
@property (assign)              BOOL                            transmitting;
@property (strong)              NSOperationQueue *              uploadOperationQueue;

- (void) incrementProgressBy: (Float64) increment;

- (void) uploadCompleted;

@end
