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

@class MMTrack;
@class ObjectiveFlickr;

@interface MMAppDelegate : NSObject <NSApplicationDelegate>

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTextField *textField;
@property (weak) IBOutlet NSSlider *slider;
@property (strong) MMTrack *track;

- (IBAction) mute: (id) sender;

- (IBAction) takeFloatValueForVolumeFrom: (id) sender;

- (void) updateUserInterface;
@end
