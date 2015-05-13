//
//  MMProgressWindowController.h
//  mugmover
//
//  Created by Bob Fitterman on 5/12/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MMProgressWindowController : NSWindowController

@property (weak)    IBOutlet    NSProgressIndicator *   progressIndicator;
@property (strong)              NSOperationQueue *      queue; // Processing transfers
@property (weak)    IBOutlet    NSButton *              stopButton;

- (void) dismiss;

@end
