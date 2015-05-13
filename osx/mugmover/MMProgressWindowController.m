//
//  MMProgressWindowController.m
//  mugmover
//
//  Created by Bob Fitterman on 5/12/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMProgressWindowController.h"

@interface MMProgressWindowController ()

@end

@implementation MMProgressWindowController

- (id) init
{
    self = [super initWithWindowNibName:@"MMProgressWindowController"];
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

/**
 * Hide the window
 */
- (void) dismiss
{
    _queue = nil;
    [self.window.sheetParent endSheet: self.window
                           returnCode: NSModalResponseCancel];
}

- (IBAction) stopButtonWasPressed:(id)sender {
    if (_queue)
    {
        [_statusMessage setStringValue: @"Stopping transfer..."];
        [_queue cancelAllOperations];
    }
}
@end
