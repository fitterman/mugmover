//
//  MMAppDelegate.m
//  mugmover
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//


#import "MMAppDelegate.h"
#import "MMSmugmug.h"
#import "MMLibraryEvent.h"
#import "MMPhotoLibrary.h"
#import "MMPhoto.h"
#import "MMFace.h"

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

    // 1. Create the master View Controller
    _masterViewController = [[MMMasterViewController alloc] initWithNibName:@"MMMasterViewController" bundle:nil];

    // 2. Add the view controller to the Window's content view
    [_window.contentView addSubview:_masterViewController.view];
    _masterViewController.view.frame = ((NSView*)_window.contentView).bounds;
    [_window.contentView setAutoresizesSubviews:YES];

    // 3. Establish the service API
    _serviceApi = [[MMSmugmug alloc] initWithHandle: @"jayphillips"];

    if (_serviceApi)
    {
        // Register for KVO on some network-associated values
        [_serviceApi addObserver: self
                      forKeyPath: @"initializationProgress"
                         options: (NSKeyValueObservingOptionNew)
                         context: (__bridge void *)(self)];
        [_serviceApi configureOauthForLibrary: _library];
    }
}

/* TODO

 From http://stackoverflow.com/questions/25833322/why-does-this-kvo-code-crash-100-of-the-time
 call  -removeObserver:forKeyPath:context:  when the time comes
*/

- (void) observeValueForKeyPath: (NSString *) keyPath
                       ofObject: (id) object
                         change: (NSDictionary *) change
                        context: (void *) context
{
    if (context == (__bridge void *) self) // Make sure it's your context that is observing
    {
        if ([keyPath isEqual: @"initializationProgress"])
        {
            NSNumber *newValue = (NSNumber *)[change objectForKey: NSKeyValueChangeNewKey];
            DDLogInfo(@"       initializationProgress=%@", newValue);
            if ([newValue floatValue] == 1.0)
            {
                self.masterViewController.serviceApi = _serviceApi;
                //[MMPhoto getPhotosFromLibrary: _library];    /* This kicks off the whole process from the database without a service */
                //[stream getPhotos]; /* This kicks off the whole process with flickr */
            }
        }
    }
    else
    {
      // if possible, you'd call
      //  [super observeValueForKeyPath: keyPath ofObject: object change: change context: context];
    }
}

- (void) close
{
    if (_library)
    {
        [_library close];
        _library = nil;
    }
    if (_serviceApi)
    {
        [_serviceApi close];
        _serviceApi = nil;
    }
}

- (void) windowDidResize: (NSNotification *) notification
{
    _masterViewController.view.frame = ((NSView*)_window.contentView).bounds;
    NSLog(@"%@", notification);
}

@end
