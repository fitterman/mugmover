//
//  MMAppDelegate.m
//  mugmover
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//


#import "MMAppDelegate.h"
#import "MMWindowController.h"

@implementation MMAppDelegate

NSDictionary *flickrPhotoPointer;

BOOL const MMdebugLevel;

- (IBAction)addLibrary:(id)sender {
    [_windowController addLibraryDialog];
}
- (IBAction)removeLibrary:(id)sender {
    [_windowController removeLibraryDialog];
}
- (IBAction)addSmugmugAccount:(id)sender {
    [_windowController addSmugmugService];
}
- (IBAction)removeAccount:(id)sender {
    [_windowController removeServiceDialog];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

- (void) applicationDidFinishLaunching: (NSNotification *) aNotification
{
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];

    [_window close]; // We don't use the system-provided window
    _windowController = [[MMWindowController alloc] initWithWindowNibName:@"MMWindowController"];
    [_windowController showWindow:nil];
}

@end
