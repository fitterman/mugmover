//
//  MMAppDelegate.m
//  mugmover
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//


#import "MMAppDelegate.h"
#import "MMFace.h"
#import "MMLibraryEvent.h"
#import "MMPhotoLibrary.h"
#import "MMPhoto.h"
#import "MMServiceManager.h"
#import "MMSmugmug.h"

#import "MMMasterViewController.h"
@interface MMAppDelegate()
@property (nonatomic, strong) IBOutlet MMMasterViewController *masterViewController;
@end

@implementation MMAppDelegate

NSDictionary *flickrPhotoPointer;

BOOL const MMdebugLevel;

- (void) applicationDidFinishLaunching: (NSNotification *) aNotification
{
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];

    [_window setDelegate: self];
    [_window setMinSize: NSMakeSize(800.0, 300.0)];

    // 1. Create the master View Controller
    _masterViewController = [[MMMasterViewController alloc] initWithNibName:@"MMMasterViewController" bundle:nil];

    // 2. Add the view controller to the Window's content view
    [_window.contentView addSubview:_masterViewController.view];
    _masterViewController.view.frame = ((NSView*)_window.contentView).bounds;
    [_window.contentView setAutoresizesSubviews:YES];
}

- (void) close
{
    NSLog(@"Can I free the window?");
}

/*- (void) windowDidResize: (NSNotification *) notification
{
    [_masterViewController.view setFrame:((NSView*)_window.contentView).bounds];
    [_masterViewController forceRedrawingOfControlsAutolayoutDoesNotRedrawAfterWindowResize];
}*/

@end
