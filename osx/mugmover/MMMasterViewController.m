    //
//  MMMasterViewController.m
//  mugmover
//
//  Created by Bob Fitterman on 4/3/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMMasterViewController.h"
#import "MMCheckboxTableCellView.h"
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
        
        NSString* imageName = [[NSBundle mainBundle] pathForResource: @"Active-128" ofType: @"gif"];
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

- (NSView *) tableView: (NSTableView *) tableView
    viewForTableColumn: (NSTableColumn *) tableColumn
                   row: (NSInteger) row
{
    NSTableCellView *baseCellView = [tableView makeViewWithIdentifier: tableColumn.identifier
                                                                owner: self];
    MMComplexTableCellView *cellView = (MMComplexTableCellView *)baseCellView;
    MMCheckboxTableCellView *checkboxCellView = (MMCheckboxTableCellView *)baseCellView;
   

    if ((tableView == _eventsTable) && _libraryEvents)
    {
        MMLibraryEvent *event = _libraryEvents[row];
        if ([tableColumn.identifier isEqualToString: @"DisplayColumn"])
        {
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
            cellView.iconField.image = nil;
        }
        else if ([tableColumn.identifier isEqualToString: @"CheckboxColumn"])
        {
            [checkboxCellView.checkboxField setState:event.toBeProcessed];
        }
    }
    else if ((tableView == _photosTable) && _photos)
    {
        MMPhoto *photo = _photos[row];
        if (photo)
        {
            if ([tableColumn.identifier isEqualToString: @"NameColumn"])
            {
                cellView.firstTitleTextField.stringValue = [photo versionName];
                cellView.imageView.image = [[NSImage alloc] initByReferencingFile: [photo fullImagePath]];
                NSString *byteSize = [NSByteCountFormatter stringFromByteCount: [[photo fileSize] longLongValue]
                                                                    countStyle: NSByteCountFormatterCountStyleFile];
                cellView.secondTextField.stringValue = [NSString stringWithFormat: @"%@ (%@)",
                                                                    [photo fileName],
                                                                    byteSize];
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
            if (event.toBeProcessed)
            {
                MMUploadOperation *uploadOperation = [[MMUploadOperation alloc] initWithEvent: event
                                                                                         from: _library
                                                                                          row: row
                                                                                      service: _library.serviceApi
                                                                               viewController: self];
                [_uploadOperationQueue addOperation: uploadOperation];
            }
            row++;
        }
        _interruptButton.enabled = YES;
    }
}

- (IBAction) checkBoxWasChecked: (id)sender
{
    NSInteger row = [_eventsTable rowForView: sender];
    if (row >= 0)
    {
        MMLibraryEvent *event = _libraryEvents[row];
        event.toBeProcessed = ((NSButton *)sender).state;
        
        // If the one they just clicked is a YES, then enable the transmit button
        if (event.toBeProcessed)
        {
            _transmitButton.enabled = YES;
            return;
        }
        // Otherwise we have to inspect all of them
        for (MMLibraryEvent *event in _libraryEvents)
        {
            if (event.toBeProcessed)
            {
                // and if one is marked for processing, enable the transmit button
                _transmitButton.enabled = YES;
                return;
            }
        }
        _transmitButton.enabled = NO;
    }
    
}

- (IBAction) interruptButtonWasPressed: (id) sender
{
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
        _eventsTable.enabled = YES;
    }
}

- (void) markEventRow: (NSInteger) row
               status: (MMEventStatus) status
                photo: (MMPhoto *) photo
{
    NSInteger colId = [_eventsTable columnWithIdentifier: @"DisplayColumn"];
    MMComplexTableCellView *selectedCellView = [_eventsTable viewAtColumn: colId
                                                                      row: row
                                                          makeIfNecessary: YES];
    if (selectedCellView)
    {
        if (status == MMEventStatusCompleted)
        {
            selectedCellView.iconField.image = _completedIcon;
        }
        else if (status == MMEVentStatusActive)
        {
            if (photo)
            {
                selectedCellView.imageView.image = [[NSImage alloc] initByReferencingFile: photo.iPhotoOriginalImagePath];
            }
            // We "optimize" this update primarily so the animation doesn't start over each
            // time a photo is sent. This can cause the animation to only show the first frame or
            // two when photos are being transmitted quickly.
            if (selectedCellView.iconField.image != _activeIcon)
            {
                selectedCellView.iconField.image = _activeIcon;
            }
        }
        else
        {
            selectedCellView.iconField.image = nil;
        }
    }
}

- (void) uploadCompletedWithStatus: (BOOL) status
{
    _eventsTable.enabled = YES;
    _interruptButton.enabled = NO;
}
@end
