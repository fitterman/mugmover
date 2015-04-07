//
//  MMMasterViewController.h
//  mugmover
//
//  Created by Bob Fitterman on 4/3/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class MMPhotoLibrary;

@interface MMMasterViewController : NSViewController

@property (weak)    IBOutlet    NSTableView *           eventsTable;
@property (weak)    IBOutlet    NSTableView *           photosTable;
@property (weak)    IBOutlet    NSButton *              transmitButton;

@property (strong)              MMPhotoLibrary *        library;
@property (strong)              NSArray *               libraryEvents;
@property (strong)              NSArray *               photos;

@end
