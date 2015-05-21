//
//  MMPrefsWindowController.m
//  mugmover
//
//  Created by Bob Fitterman on 5/19/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMPrefsManager.h"
#import "MMPrefsWindowController.h"

@interface MMPrefsWindowController ()

@end

@implementation MMPrefsWindowController

- (id) init
{
    self = [super initWithWindowNibName:@"MMPrefsWindowController"];
    return self;
}

- (IBAction)closeButtonWasPressed:(id)sender
{
    [MMPrefsManager setBool: [_retransmitFiles state]
                     forKey: @"retransmitFilesSentPreviously"];
    [self.window.sheetParent endSheet: self.window
                           returnCode: NSModalResponseCancel];
}

- (void) windowDidLoad
{
    [super windowDidLoad];
    [_retransmitFiles setState: [MMPrefsManager boolForKey: @"retransmitFilesSentPreviously"]];
}

@end
