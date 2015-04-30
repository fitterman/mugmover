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

@interface MMAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>

@property (weak)                IBOutlet    NSWindow *window;

- (void) close;

@end
