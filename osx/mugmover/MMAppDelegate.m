//
//  MMAppDelegate.m
//  mugmover
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//


#import "MMAppDelegate.h"
#import "MMPrefsWindowController.h"
#import "MMWindowController.h"

@implementation MMAppDelegate

NSDictionary *flickrPhotoPointer;

BOOL const MMdebugLevel;

#pragma mark Actions
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

- (IBAction)editPreferences:(id)sender {
    // we keep a reference to hold it finishes executing
    _prefsWindowController = [MMPrefsWindowController new];
    [_windowController.window beginSheet:[_prefsWindowController window]
                       completionHandler: ^(NSModalResponse returnCode) {
              _prefsWindowController = nil;
    }];
}

#pragma mark Delegate methods

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

- (void) applicationDidFinishLaunching: (NSNotification *) aNotification
{
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [MMPrefsWindowController setDefaultPreferenceValues];
    
    [_window close]; // We don't use the system-provided window
    _windowController = [[MMWindowController alloc] initWithWindowNibName:@"MMWindowController"];
    [_windowController showWindow:nil];
}

@end
