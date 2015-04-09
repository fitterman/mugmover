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
#import "MMSmugmug.h"
#import "MMUploadOperation.h"

@implementation MMMasterViewController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        // TODO How to release this before Yosemite as there is no viewWillDisappear
        _uploadOperationQueue = [[NSOperationQueue alloc] init];
        _uploadOperationQueue.name = @"Upload Queue";
        _uploadOperationQueue.MaxConcurrentOperationCount = 1;
        
        _outstandingRequests = 0;
        
        NSString* imageName = [[NSBundle mainBundle] pathForResource: @"Active-128" ofType: @"png"];
        _activeIcon = [[NSImage alloc] initWithContentsOfFile:imageName];
        imageName = [[NSBundle mainBundle] pathForResource: @"Completed-128" ofType: @"png"];
        _completedIcon = [[NSImage alloc] initWithContentsOfFile:imageName];
    }
    return self;
}

- (void) dealloc
{
    _uploadOperationQueue = nil;
}

- (NSView *) tableView:(NSTableView *) tableView
    viewForTableColumn:(NSTableColumn *) tableColumn
                   row:(NSInteger)row
{
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
            cellView.imageView.image = [[NSImage alloc] initByReferencingFile: [event iconImagePath]];
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
                cellView.imageView.image = [[NSImage alloc] initByReferencingFile: [photo fullImagePath]];
                cellView.secondTextField.stringValue = [[photo fileSize] stringValue];
            }
        }
    }
    return cellView;
}


- (NSInteger) numberOfRowsInTableView: (NSTableView *) tableView
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

- (BOOL) selectionShouldChangeInTableView: (NSTableView * ) tableView
{
    if (tableView == _photosTable)
    {
        return NO;
    }
    return YES;
    
}
- (IBAction) transmitButtonWasPressed: (id) sender {
    if (sender == _transmitButton)
    {
        _transmitButton.enabled = NO;
        _eventsTable.enabled = NO;
        NSInteger row = 0;
        for (MMLibraryEvent *event in _libraryEvents)
        {
            MMUploadOperation *uploadOperation = [[MMUploadOperation alloc] initWithEvent: event
                                                                                     from: _library
                                                                                      row: row
                                                                                  service: _library.serviceApi
                                                                           viewController: self];
            [_uploadOperationQueue addOperation: uploadOperation];
            row++;
        }
        _interruptButton.enabled = YES;
    }
}

- (IBAction) interruptButtonWasPressed: (id) sender {
    if (sender == _interruptButton)
    {
        [_uploadOperationQueue cancelAllOperations];
    }
}

- (void) tableViewSelectionDidChange: (NSNotification *) notification
{
    NSTableView *tableView = notification.object;
    if (tableView == _eventsTable)
    {
        _selectedRow = tableView.selectedRow;
        _selectedEvent = _libraryEvents[_selectedRow];
        for (MMPhoto *photo in _photos)
        {
            [photo close];
        }
        _photos = [MMPhoto getPhotosFromLibrary: _library forEvent: _selectedEvent];
        [_photosTable reloadData];
        _transmitButton.enabled = YES;
        _eventsTable.enabled = YES;
    }
}

- (void) markEventRow: (NSInteger) row
                   as: (MMEventStatus) status
{
    NSInteger colId = [_eventsTable columnWithIdentifier: @"OnlyColumn"];
    MMComplexTableCellView *selectedCellView = [_eventsTable viewAtColumn: colId
                                                                      row: row
                                                          makeIfNecessary: NO];
    if (selectedCellView)
    {
        if (status == MMEventStatusCompleted)
        {
            selectedCellView.iconField.image = _completedIcon;
        }
        else if (status == MMEVentStatusActive)
        {
            selectedCellView.iconField.image = _activeIcon;
        }
        else
        {
            selectedCellView.iconField.image = nil;
        }
    }
}

- (void) uploadCompletedWithStatus: (BOOL) status
{
    _transmitButton.enabled = YES;
    _eventsTable.enabled = YES;
    _interruptButton.enabled = NO;
}
@end
