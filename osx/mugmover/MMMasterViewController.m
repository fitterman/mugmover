//
//  MMMasterViewController.m
//  mugmover
//
//  Created by Bob Fitterman on 4/3/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMMasterViewController.h"
#import "MMComplexTableCellView.h"
#import "MMLibraryEvent.h"
#import "MMPhoto.h"
#import "MMUiUtility.h"

@implementation MMMasterViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
    }
    return self;
}

- (NSView *) tableView:(NSTableView *) tableView
    viewForTableColumn:(NSTableColumn *) tableColumn
                   row:(NSInteger)row
{
    
    // Get a new ViewCell
    MMComplexTableCellView *cellView = [tableView makeViewWithIdentifier: tableColumn.identifier
                                                            owner: self];
    if ((tableView == _eventsTable) && _libraryEvents)
    {
        if ([tableColumn.identifier isEqualToString:@"OnlyColumn"])
        {
            MMLibraryEvent *event = _libraryEvents[row];
            cellView.firstTitleTextField.stringValue = [event name];
            if ((!cellView.firstTitleTextField.stringValue) ||
                ([cellView.firstTitleTextField.stringValue length] == 0))
            {
                cellView.firstTitleTextField.stringValue = @"(none)";
            }

            cellView.secondTextField.stringValue = [NSString stringWithFormat: @"%@ (%@)",
                                                                [event dateRange],
                                                                [event filecount]];
        }
    }
    else if ((tableView == _photosTable) && _photos)
    {
        MMPhoto *photo = _photos[row];
        if (photo)
        {
            if ([tableColumn.identifier isEqualToString: @"NameColumn"])
            {
                cellView.firstTitleTextField.stringValue = [photo fileName];
                cellView.imageView.image = [[NSImage alloc ] initByReferencingFile: [photo fullImagePath]];
                cellView.secondTextField.stringValue = [[photo fileSize] stringValue];
            }
        }
    }
    return cellView;
}


- (NSInteger)numberOfRowsInTableView: (NSTableView *) tableView
{
    if (tableView == _eventsTable)
    {
        return [_libraryEvents count];
    }
    else if (tableView == _photosTable)
    {
        if (_photos)
        {
            return [_photos count];
        }
    }
    return 0;
}

- (BOOL)selectionShouldChangeInTableView: (NSTableView * ) tableView
{
    if (tableView == _photosTable)
    {
        return NO;
    }
    return YES;
    
}
- (IBAction)transmitButtonWasPressed: (id) sender {
    if (sender == _transmitButton)
    {
        if ([_library startUploading])
        {
            _transmitButton.enabled = NO;
        }
        else
        {
            if ([MMUiUtility alertWithText: @"Uploading already in progress."
                              withQuestion: nil
                                     style: NSWarningAlertStyle])
            {
                
            }
        }
        NSLog(@"sender=%@", sender);
    }
}

- (void)tableViewSelectionDidChange: (NSNotification *) notification
{
    NSTableView *tableView = notification.object;
    if (tableView == _eventsTable)
    {
        NSInteger row = tableView.selectedRow;
        MMLibraryEvent *event = _libraryEvents[row];
        for (MMPhoto *photo in _photos)
        {
            [photo close];
        }
        _photos = [MMPhoto getPhotosFromLibrary: _library forEvent: event];
        [_photosTable reloadData];
        _transmitButton.enabled = YES;
    }
}
@end
