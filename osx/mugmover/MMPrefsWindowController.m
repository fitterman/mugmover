//
//  MMPrefsWindowController.m
//  mugmover
//
//  Created by Bob Fitterman on 5/19/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

/**
 * This is documentation on what each of the preference settings does.
 *
 * Reprocess All Images In Selected Events
 *   Every photo that is uploaded is recorded locally, and its unique ID (for that one service) is
 * is stored within the Mugmover app. If a particular photo is sent to a different service, 
 * its treatment with regard to this preference setting is in relation to a single service. Sending
 * the same photo to a second or third service or account with the same service will have be treated
 * as a separate occurrence.
 *   Normally any image which has been recorded as having been uploaded to a particular service
 * will never be reprocessed. This is the behavior when this option is not checked.
 *   When this option is checked, files that have never previously been sent to a given service will
 * be treated as would be the usual case: they will be uploaded and their assigned ID for that service
 * will be recorded. The remaining files will be transmitted to the service as a replacement 
 * for the existing file for that service and/or account. If the file is no longer found at the
 * service, it will be transmitted as a new file and the stored ID will updated. Once transmitted, 
 * the Mugmarker record will be updated as well.
 *   Smugmug will replace the original image regardless of where it is stored in the folder/gallery
 * structure. Moving it will not cause it to be treated as "not found," only deleting the file will 
 * have that result.
 *
 *
 */
#import "MMPrefsManager.h"
#import "MMPrefsWindowController.h"

@interface MMPrefsWindowController ()

@end

@implementation MMPrefsWindowController

- (id) init
{
    self = [super initWithWindowNibName:@"MMPrefsWindowController"];
    return self;
}

- (IBAction)closeButtonWasPressed:(id)sender
{
    [MMPrefsManager setBool: [_reprocessAllImagesPreviouslyTransmitted state]
                     forKey: @"reprocessAllImagesPreviouslyTransmitted"];
    [self.window.sheetParent endSheet: self.window
                           returnCode: NSModalResponseCancel];
}

- (void) windowDidLoad
{
    [super windowDidLoad];
    [_reprocessAllImagesPreviouslyTransmitted setState: [MMPrefsManager boolForKey: @"reprocessAllImagesPreviouslyTransmitted"]];
}

@end
