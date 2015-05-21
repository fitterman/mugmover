//
//  MMWindowController.h
//  
//
//  Created by Bob Fitterman on 5/18/15.
//
//

#import <Cocoa/Cocoa.h>
@class MMLibraryEvent;
@class MMPhotoLibrary;
@class MMPhotoLibraryManager;
@class MMPrefsWindowController;
@class MMProgressWindowController;
@class MMServiceManager;

@interface MMWindowController : NSWindowController <NSWindowDelegate, NSTableViewDelegate, NSSplitViewDelegate>

@property (weak)    IBOutlet    NSView *                windowView;

@property (weak)    IBOutlet    NSButton *              checkAllButton;
@property (weak)    IBOutlet    NSTableView *           eventsTable;
@property (weak)    IBOutlet    NSSegmentedControl *    librariesSegmentedControl;
@property (weak)    IBOutlet    NSTableView *           librariesTable;
@property (weak)    IBOutlet    NSTableView *           photosTable;
@property (weak)    IBOutlet    NSSegmentedControl *    servicesSegmentedControl;
@property (weak)    IBOutlet    NSTableView *           servicesTable;
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

- (void) addLibraryDialog;

- (void) addSmugmugService;

- (void) incrementProgressBy: (Float64) increment;

- (void) removeLibraryDialog;

- (void) removeServiceDialog;

- (void) setActivePhotoThumbnail: (NSImage *) photoThumbnailImage;

- (void) uploadCompleted;

@end
