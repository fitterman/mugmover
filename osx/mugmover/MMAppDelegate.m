//
//  MMAppDelegate.m
//  mugmover
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//


#import "MMAppDelegate.h"
#import "MMTrack.h"
#import "MMFlickrPhotostream.h"
#import "MMPhotoLibrary.h"
#import "MMPhoto.h"
#import "MMFace.h"

@implementation MMAppDelegate

MMFlickrPhotostream *stream = nil;
MMPhotoLibrary *photoLibrary = nil;
NSDictionary *flickrPhotoPointer;

BOOL const MMdebugging = NO;

- (void)applicationDidFinishLaunching: (NSNotification *)aNotification
{
    MMTrack *aTrack = [[MMTrack alloc] init];
    [self setTrack: aTrack]; /* alternatively, self.track = aTrack; */
    [self updateUserInterface];
    
    stream = [[MMFlickrPhotostream alloc] initWithHandle: @"jayphillipsstudio" //barackobamadotcom"
                                             libraryPath: @"/Users/bob/Projects/mugmover/Sample Library"];
    if (stream)
    {
        // Register for KVO on some network-associated values
        [stream addObserver: self
                 forKeyPath: @"initializationProgress"
                    options: (NSKeyValueObservingOptionNew)
                    context: (__bridge void *)(self)];
        [stream addObserver: self
                 forKeyPath: @"currentPhoto"
                    options: (NSKeyValueObservingOptionNew)
                    context: (__bridge void *)(self)];
    }
    
}

/* TODO 
 
 From http://stackoverflow.com/questions/25833322/why-does-this-kvo-code-crash-100-of-the-time
 call  -removeObserver:forKeyPath:context:  when the time comes
*/

- (void)observeValueForKeyPath: (NSString *)keyPath
                      ofObject: (id)object
                        change: (NSDictionary *)change
                       context: (void *)context {
    if (context == (__bridge void *)self) // Make sure it's your context that is observing
    {
        if ([keyPath isEqual: @"initializationProgress"])
        {
            NSNumber *newValue = (NSNumber *)[change objectForKey: NSKeyValueChangeNewKey];
            // NSLog(@"      initializationProgress=%@", newValue);
            if ([newValue floatValue] == 1.0)
            {
                [stream nextPhoto]; /* This kicks off the whole process */
            }
        }
        else if ([keyPath isEqual: @"currentPhoto"])
        {
            MMPhoto *photoObj = (MMPhoto *)[change objectForKey: NSKeyValueChangeNewKey];
            
            NSLog(@"%lu/%lu", (long)stream.currentPhotoIndex + 1, (long)stream.photosInStream);
            if (photoObj)
            {
                NSLog(@"  url=%@", photoObj.smallUrl);
                
                if ([photoObj findMatchingInIphotoLibraryByVersionUuidAndVersion])
                {
                    NSLog(@"FOUND MATCH 1  versionUuid=%@ version=%ld", photoObj.versionUuid, photoObj.version);
                    [photoObj processPhoto];
                }
                else
                {
                    // TODO Add a counter here to keep track of how often this fails
                    // We now request the photo sizes and when that returns,
                    // we can look for a matching image.
                    [photoObj fetchFlickrSizes];
                }
            }
            if (stream.currentPhotoIndex + 1 < stream.photosInStream)
            {
                [stream nextPhoto]; /* There are more left to get. */
            }
        }
    }
    else
    {
      // if possible, you'd call
      //  [super observeValueForKeyPath: keyPath ofObject: object change: change context: context];
    }
}

- (IBAction)mute: (id)sender
{
    self.track.volume = 0.0;
    /* WAS [self.track setVolume: 0.0]; */
    [self updateUserInterface];
}

- (IBAction)takeFloatValueForVolumeFrom: (id)sender
{
    float newValue = [sender floatValue];
    [self.track setVolume: newValue];
    [self updateUserInterface];

    NSString *senderName = nil;
    if (sender == self.textField) {
        senderName = @"textField";
    }
    else {
        senderName = @"slider";
    }
    // NSLog(@"%@ sent takeFloatValueForVolumeFrom: with value %1.2f", senderName, [sender floatValue]);
}

- (void)updateUserInterface
{
    
    float volume = [self.track volume];
    [self.textField setFloatValue: volume];
    [self.slider setFloatValue: volume];
}


@end
