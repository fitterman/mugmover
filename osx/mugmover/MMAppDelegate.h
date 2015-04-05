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

@class MMPhotoLibrary;

@interface MMAppDelegate : NSObject <NSApplicationDelegate>

@property (weak)    IBOutlet    NSWindow *window;
@property (strong)              MMPhotoLibrary *        library;


- (void) close;

@end
