//
//  MMPrefsWindowController.h
//  mugmover
//
//  Created by Bob Fitterman on 5/19/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MMPrefsWindowController : NSWindowController
@property (weak)    IBOutlet    NSButton *          closeButton;
@property (weak)    IBOutlet    NSButton *          reprocessAllImagesPreviouslyTransmitted;

@end
