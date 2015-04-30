//
//  MMAppDelegate.m
//  mugmover
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//


#import "MMAppDelegate.h"
#import "MMMasterViewController.h"

@interface MMAppDelegate()
@property (nonatomic, strong) IBOutlet MMMasterViewController *masterViewController;
@end

@implementation MMAppDelegate

NSDictionary *flickrPhotoPointer;

BOOL const MMdebugLevel;

- (void) applicationDidFinishLaunching: (NSNotification *) aNotification
{
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];

    [_window setDelegate: self];
    [_window setMinSize: NSMakeSize(800.0, 300.0)];

    /* 1. Create the master View Controller */
    _masterViewController = [[MMMasterViewController alloc] initWithNibName:@"MMMasterViewController" bundle:nil];

    /* 2. Add the view controller to the Window's content view */
    [_window.contentView addSubview:_masterViewController.view];

    /* 3. Make sure the autolayout stuff is set up properly */
    _masterViewController.view.translatesAutoresizingMaskIntoConstraints = NO;     NSDictionary* views = @{ @"view": _masterViewController.view };
    NSArray* constraints = [NSLayoutConstraint constraintsWithVisualFormat: @"H:|[view]|"
                                                                   options: 0
                                                                   metrics: nil
                                                                     views: views];
    [_window.contentView addConstraints:constraints];
    constraints = [NSLayoutConstraint constraintsWithVisualFormat: @"V:|[view]|"
                                                          options: 0
                                                          metrics: nil
                                                            views: views];
    [_window.contentView addConstraints:constraints];
}

- (void) close
{
    NSLog(@"Can I free the window?");
}

@end
