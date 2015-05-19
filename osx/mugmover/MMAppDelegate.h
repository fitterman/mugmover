//
//  MMAppDelegate.h
//  mugmover
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "DDASLLogger.h"
#import "DDTTYLogger.h"
#import "DDFileLogger.h"
@class MMWindowController;

@interface MMAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>

@property (weak)    IBOutlet    NSWindow *                  window;
@property (weak)    IBOutlet    NSMenuItem *                toggleFullScreen;
@property (strong)              MMWindowController *        windowController;
- (void) close;

@end
