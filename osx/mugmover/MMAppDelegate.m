//
//  MMAppDelegate.m
//  mugmover
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//


#import "MMAppDelegate.h"
#import "MMTrack.h"
#import "MMFlickr.h"
#import "MMFlickrPhotostream.h"
#import "MMSmugmugOauth.h"
#import "MMPhotoLibrary.h"
#import "MMPhoto.h"
#import "MMFace.h"

@implementation MMAppDelegate

MMFlickrPhotostream *stream = nil;
MMFlickr *flickr = nil;
MMSmugmugOauth *smugmug = nil;
NSDictionary *flickrPhotoPointer;

BOOL const MMdebugLevel;

- (void) applicationDidFinishLaunching: (NSNotification *) aNotification
{
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];

    MMTrack *aTrack = [[MMTrack alloc] init];
    [self setTrack: aTrack]; /* alternatively, self.track = aTrack; */
    [self updateUserInterface];

//    flickr = [[MMFlickr alloc] initWithHandle: @"jayphillip"
//                                    libraryPath: @"/Users/Bob/Pictures/Jay Phillips"];

    smugmug = [[MMSmugmugOauth alloc] initAndStartAuthorization];
//    stream = [[MMFlickrPhotostream alloc] initWithHandle: @"jayphillipsstudio" //barackobamadotcom"
//                                             libraryPath: @"/Users/Bob/Pictures/Laks and Schwartz Family Photos"];
//                                               libraryPath: @"/Users/Bob/Pictures/Jay Phillips"];
    if (stream)
    {
        // Register for KVO on some network-associated values
        [stream addObserver: self
                 forKeyPath: @"initializationProgress"
                    options: (NSKeyValueObservingOptionNew)
                    context: (__bridge void *)(self)];
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
                [stream.library getPhotos];    /* This kicks off the whole process from the database without a service */
                // [stream getPhotos]; /* This kicks off the whole process with flickr */
            }
        }
    }
    else
    {
      // if possible, you'd call
      //  [super observeValueForKeyPath: keyPath ofObject: object change: change context: context];
    }
}

- (IBAction) mute: (id) sender
{
    self.track.volume = 0.0;
    /* WAS [self.track setVolume: 0.0]; */
    [self updateUserInterface];
}

- (IBAction) takeFloatValueForVolumeFrom: (id) sender
{
    float newValue = [sender floatValue];
    [self.track setVolume: newValue];
    [self updateUserInterface];

    NSString *senderName = nil;
    if (sender == self.textField)
    {
        senderName = @"textField";
    }
    else
    {
        senderName = @"slider";
    }
    DDLogInfo(@"%@ sent takeFloatValueForVolumeFrom: with value %1.2f", senderName, [sender floatValue]);
}

- (void) updateUserInterface
{

    float volume = [self.track volume];
    [self.textField setFloatValue: volume];
    [self.slider setFloatValue: volume];
}


@end
