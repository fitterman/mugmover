//
//  MMDestinationFileSystem.m
//  mugmover
//
//  Created by Bob Fitterman on 12/7/16.
//  Copyright © 2016 Dicentra LLC. All rights reserved.
//

#import "MMDestinationAbstract.h"
#import "MMDestinationFileSystem.h"
#import "MMFileUtility.h"
#import "MMLibraryEvent.h"
#import "MMPhoto.h"
#import "MMPrefsManager.h"
#import "MMWindowController.h"
#import "MMUploadOperation.h"

@implementation MMDestinationFileSystem

NSString *destTypeIdentifier = @"filesystem";

- (id) initFromDictionary: (NSDictionary *) dictionary
{
    self = [super init];
    if ((self) &&
        (dictionary && [[dictionary valueForKey: @"type"] isEqualToString: destTypeIdentifier]))
    {
        self.uniqueId = [dictionary valueForKey: @"id"];
    }
    return self;
}

/**
 * This method returns an NSString pointer if it succeeds. The return value is the full path
 * to the folder (if success), otherwise a nil value is returned.
 * It looks for a folder, creates it if it doesn't exist. The folder should contain also have a
 * hidden file called ".mugmover" which will help track the mapping of iPhoto events to 
 * file system folders.
 */
- (NSString *) findOrCreateFolderForLibrary: (MMPhotoLibrary *) library
{
    NSString *path = [self.uniqueId stringByExpandingTildeInPath];
    NSURL *pathUrl = [NSURL fileURLWithPath: path
                                isDirectory: YES];
    NSError *error = nil;

    if (![[NSFileManager defaultManager] fileExistsAtPath: path])
    {
        [[NSFileManager defaultManager] createDirectoryAtURL: pathUrl
                                 withIntermediateDirectories: YES
                                                  attributes: nil
                                                       error: &error];
        if (error)
        {
            return nil; /* Something went wrong with the create */
        }
    }
    // Look for the hidden file and attempt to deserialize it
    NSURL *hiddenFileUrl = [pathUrl URLByAppendingPathComponent: @".mugmover"];
    
    // Sloppy, but it's local so let's go synchronous

    NSURLRequest *request = [[NSURLRequest alloc] initWithURL: hiddenFileUrl];
    NSData *fileContents = [NSURLConnection sendSynchronousRequest: request
                                                 returningResponse: nil
                                                             error: &error];
    if (error)
    {
        if (error.code == -1100) // File not found
        {
            _eventDictionary = @{};
        }
        else
        {
            // TODO Report the error, then return
            return nil;
        }
    }
    else
    {
        _eventDictionary = [NSJSONSerialization JSONObjectWithData: fileContents
                                                           options: 0
                                                             error: &error];
        if (error)
        {
            // TODO Report corrupted JSON file, then start clean.
            _eventDictionary = @{};
        }
    }
    return [pathUrl path]; // The full path to the destination folder, including "/"
}

- (NSString *) identifier
{
    return destTypeIdentifier;
}

- (NSString *) name
{
    NSString *dirname = [self.uniqueId lastPathComponent];
    return [NSString stringWithFormat: @"%@ (File System)\n%@", dirname, self.uniqueId];
}

- (NSString *) oauthAccessToken
{
    return @"";
}

- (NSString *) oauthTokenSecret
{
    return @"";
}

/**
 * "private" method for finding the destination directory. 
 * It creates the directory if necessary.
 * TODO It will hunt down the directory even if the event has been renamed.
 */
- (NSString *) findDestinationDirectoryForEvent: (MMLibraryEvent *) event
                             underDirectoryPath: parentDirectoryPath
{
    NSString *name = [event name];
    if ((!name) || ([name length] == 0))
    {
        name = [event dateRange];
    }
 
    name = [name stringByReplacingOccurrencesOfString: @"/" withString: @"\\f"];
    NSString *eventDirectoryName = [NSString stringWithFormat: @"%@ (%@)", name, [event uuid]];
    NSString *pathToDestinationDirectory = [NSString pathWithComponents: @[parentDirectoryPath, eventDirectoryName]];
 
    // Go for an exact match
    BOOL isDir = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath: pathToDestinationDirectory
                                             isDirectory: &isDir] && isDir)
    {
        return pathToDestinationDirectory;
    }
    
    // See if there's a directory with a name that matches the uuid in parentheses
    
    NSError *error;
    NSArray *directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath: parentDirectoryPath
                                                                                     error: &error];
    NSString *match = [NSString stringWithFormat: @"*(%@)*", [event uuid]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF like %@", match];
    NSArray *subdirs = [directoryContents filteredArrayUsingPredicate:predicate];
    
    // Now make sure it exists (and is a directory) or create it

    for (id dirpath in subdirs)
    {
        isDir = NO;
        NSString *fullpath = [NSString pathWithComponents: @[parentDirectoryPath, dirpath]];
        if ([[NSFileManager defaultManager] fileExistsAtPath: fullpath
                                                 isDirectory: &isDir] && isDir)
        {
            // Found a matching directory, rename it
            [[NSFileManager defaultManager] moveItemAtPath: fullpath
                                                    toPath: pathToDestinationDirectory
                                                     error: &error];
            if (error)
            {
                DDLogError(@"Unable to move ""%@"" to ""%@""", fullpath, pathToDestinationDirectory);
                continue; // consider another possibility, if there is more than one (unlikely)
            }
            // Look no more
            return fullpath;
        }
        // do something with object
    }

    if(![[NSFileManager defaultManager] fileExistsAtPath: pathToDestinationDirectory])
    {
        [[NSFileManager defaultManager] createDirectoryAtPath: pathToDestinationDirectory
                                  withIntermediateDirectories: YES
                                                   attributes: nil
                                                        error: &error];
    }
    
    if (error)
    {
        DDLogError(@"Unable to create directory (%@) for transfer, error %@",
                   pathToDestinationDirectory, error);
        return nil; // TODO return is the right way to handle this, correct?
    }
    return pathToDestinationDirectory;
}

/**
 * Tightly connected to the MMUploadOperation class. This is what does the
 * actual transfer.
 */
- (void) transferPhotosForEvent: (MMLibraryEvent *) event
                uploadOperation: (MMUploadOperation *) uploadOperation
               windowController: (MMWindowController *) windowController
                       folderId: (NSString *) folderId /* directory name for export */
{
    @autoreleasepool
    {
        NSString *pathToDestinationDirectory = [self findDestinationDirectoryForEvent: event
                                                                   underDirectoryPath: folderId];
        
        if (!pathToDestinationDirectory)
        {
            return; // TODO Verify this is the right action if you can't find/create the directory
        }
        
        // Restore the preferences (defaults)
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        BOOL reprocessAllImagesPreviouslyTransmitted = [MMPrefsManager
                                                        boolForKey: @"reprocessAllImagesPreviouslyTransmitted"];
        NSString *albumKey = [NSString stringWithFormat: @"%@.%@.albums.%@",
                              destTypeIdentifier,
                              self.uniqueId,
                              [event uuid]];
        NSArray *photos = [MMPhoto getPhotosForEvent: event];

        // For file transfers, we generate a script that can be used to update the Exif
        // data after the export. It's an array of strings, two per file. (one for echo,
        // one for exiftool). There's an extra so we can get a terminal newline in the file.
        NSMutableArray *scriptCommands = [[NSMutableArray alloc] initWithCapacity: (2 * [photos count]) + 1];

        // Get the preferences (defaults) for this event within this service
        NSMutableDictionary *albumState = [[defaults objectForKey: albumKey] mutableCopy];

        NSInteger completedTransfers = 0;
        NSInteger allCounter = 0;
        MMEventStatus finalStatus = MMEventStatusIncomplete; // Assume something goes wrong
        
        for (MMPhoto *photo in photos)
        {
            NSError *error = nil;
            allCounter++;
            
            // Before processing the next photo, see if we've been asked to abort
            if (uploadOperation.isCancelled)
            {
                break;
            }
            
            error = [photo processPhoto];
            if (error)
            {
                [self logError: error];
                NSLog(@"ERROR >> %@", error);
                continue;
            }
            
            if ((allCounter % 10) == 1)
            {
                NSImage *currentPhotoThumbnail = [photo getThumbnailImage];
                [event setActivePhotoThumbnail: currentPhotoThumbnail
                                    withStatus: MMEventStatusActive];
                [windowController setActivePhotoThumbnail: currentPhotoThumbnail];
                [[NSOperationQueue mainQueue] addOperationWithBlock: ^(void)
                     {
                         [windowController.eventsTable reloadData];
                     }
                 ];
            }
            NSString *copiedFilePath = nil;
            
            BOOL imageRequiresConversion = [photo isFormatRequiringConversion];
            if (imageRequiresConversion)
            {
                // TODO Fix this to overwrite if exists
                copiedFilePath = [MMFileUtility jpegFromPath: photo.iPhotoOriginalImagePath
                                                 toDirectory: pathToDestinationDirectory];

            }
            else
            {
                copiedFilePath = [MMFileUtility copyFileAtPath: photo.iPhotoOriginalImagePath
                                                   toDirectory: pathToDestinationDirectory];
                // Instead of converting the image, we can just copy it over.
            }
            if (!copiedFilePath)
            {
                DDLogError(@"Failed to create JPEG to %@ (at %@, from %@)", photo,
                           pathToDestinationDirectory, photo.iPhotoOriginalImagePath);
                break; // TODO Verify we want to break out of the loop.
            }
            
            NSString* cmd = [NSString stringWithFormat: @"echo '%@'", copiedFilePath];
            [scriptCommands addObject: cmd];
            cmd = [NSString stringWithFormat: @"exiftool '%@' -DateTimeOriginal='%@' -Description=%@",
                                copiedFilePath,
                                [photo.originalDate stringByReplacingOccurrencesOfString: @"-" withString: @":"],
                                [MMFileUtility bashEscapedString: [photo formattedDescription]]];
            [scriptCommands addObject: cmd];

            completedTransfers++;
            [windowController incrementProgressBy: 1.0];
        }
        
        finalStatus = (completedTransfers == [photos count]) ? MMEventStatusCompleted : MMEventStatusIncomplete;

        // Create the exiftool command file
        
        // First we concatenate the strings
        [scriptCommands addObject: @""]; // Empty string helps to add the terminal newline
        NSString *exiftoolCommands = [scriptCommands componentsJoinedByString: @"\n"];
        
        // Then we write them to the file
        NSError *writeError = nil;
        NSString *exiftoolFile = [pathToDestinationDirectory stringByAppendingPathComponent: @"xt.sh"];
        
        [[NSFileManager defaultManager] createFileAtPath: exiftoolFile
                                                    contents: nil
                                                  attributes: @{ NSFilePosixPermissions : @0544 }];
        
        [exiftoolCommands writeToFile: exiftoolFile
                           atomically: YES
                             encoding: NSUTF8StringEncoding
                                error: &writeError];
        if (writeError != nil)
        {
            finalStatus = MMEventStatusIncomplete;    // TODO Do something
        }
        

        // And at the end we have to do it in case some change(s) did not get stored
        [defaults setObject: albumState forKey: albumKey];

        // Restore the display to the default image for this album
        [event setActivePhotoThumbnail: nil withStatus: finalStatus];
        [[NSOperationQueue mainQueue] addOperationWithBlock: ^(void)
         {
             [windowController.eventsTable reloadData];
         }];
 
    }
}

@end
