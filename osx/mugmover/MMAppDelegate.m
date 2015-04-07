//
//  MMAppDelegate.m
//  mugmover
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//


#import "MMAppDelegate.h"
#import "MMFlickrPhotostream.h"
#import "MMSmugmug.h"
#import "MMLibraryEvent.h"
#import "MMPhotoLibrary.h"
#import "MMPhoto.h"
#import "MMFace.h"

#import "MMMasterViewController.h"
@interface MMAppDelegate()
@property (nonatomic,strong) IBOutlet MMMasterViewController *masterViewController;
@end

@implementation MMAppDelegate

MMFlickrPhotostream *stream = nil;
MMSmugmug *smugmug = nil;
NSDictionary *flickrPhotoPointer;

BOOL const MMdebugLevel;

- (void) applicationDidFinishLaunching: (NSNotification *) aNotification
{
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];

    // 1. Create the master View Controller
    self.masterViewController = [[MMMasterViewController alloc] initWithNibName:@"MMMasterViewController" bundle:nil];

    // 2. Populate the library and libraryEvents
    _library = [[MMPhotoLibrary alloc] initWithPath: (NSString *) @"/Users/Bob/Pictures/Jay Phillips"];
    if (_library)
    {
        self.masterViewController.library = _library;
        self.masterViewController.libraryEvents = [MMLibraryEvent getEventsFromLibrary: _library];

        // 3. Add the view controller to the Window's content view
        [self.window.contentView addSubview:self.masterViewController.view];
        self.masterViewController.view.frame = ((NSView*)self.window.contentView).bounds;
    }
/*
   smugmug = [[MMSmugmug alloc] initWithHandle: @"jayphillips"];

   // stream = [[MMFlickrPhotostream alloc] initWithHandle: @"jayphillipsstudio" //barackobamadotcom"
   //  //                                        libraryPath: @"/Users/Bob/Pictures/Laks and Schwartz Family Photos"];
   //                                            libraryPath: @"/Users/Bob/Pictures/Jay Phillips"];
    if (smugmug)
    {
        // Register for KVO on some network-associated values
        [smugmug addObserver: self
                  forKeyPath: @"initializationProgress"
                     options: (NSKeyValueObservingOptionNew)
                     context: (__bridge void *)(self)];
    }
    [smugmug configureOauth: [_library.databaseUuid uppercaseString]];
 */
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
                [MMPhoto getPhotosFromLibrary: _library];    /* This kicks off the whole process from the database without a service */
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
}


@end
