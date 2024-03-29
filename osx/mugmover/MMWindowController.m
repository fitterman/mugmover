//
//  MMWindowController.m
//  
//
//  Created by Bob Fitterman on 5/18/15.
//
//

#import "MMWindowController.h"
#import "MMCheckboxTableCellView.h"
#import "MMComplexTableCellView.h"
#import "MMLibraryEvent.h"
#import "MMPhoto.h"
#import "MMPhotoLibrary.h"
#import "MMPhotoLibraryManager.h"
#import "MMProgressWindowController.h"
#import "MMUiUtility.h"
#import "MMDestinationManager.h"
#import "MMDestinationFileSystem.h"
#import "MMDestinationSmugmug.h"
#import "MMUploadOperation.h"


@implementation MMWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    // These things should go in the initalizer, perhaps
    _uploadOperationQueue = [[NSOperationQueue alloc] init];
    _uploadOperationQueue.name = @"Upload Queue";
    _uploadOperationQueue.maxConcurrentOperationCount = 1;

    _outstandingRequests = 0;

    _activeIcon = [MMUiUtility iconImage: @"Active-128" ofType: @"gif"];
    _completedIcon = [MMUiUtility iconImage: @"Completed-128" ofType: @"png"];
    _incompleteIcon = [MMUiUtility iconImage: @"Incomplete-128" ofType: @"png"];
    _libraryIcon = [MMUiUtility iconImage: @"Library-128" ofType: @"png"];
    _destinationIcon = [MMUiUtility iconImage: @"Service-128" ofType: @"png"];
    _transmitting = NO;

    _libraryManager = [[MMPhotoLibraryManager alloc] initForWindowController: self];
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex: 0];
    [_librariesTable reloadData];
    [_librariesTable selectRowIndexes: indexSet
                 byExtendingSelection: NO];
    _destinationManager = [[MMDestinationManager alloc] initForWindowController: self];
    [_destinationsTable reloadData];
    [_destinationsTable selectRowIndexes: indexSet
                byExtendingSelection: NO];
}


- (void) windowWillClose: (NSNotification *) notification
{
    _uploadOperationQueue = nil;
}

/**
 * If +hint+ is set to YES, then we know for certain something is marked for tranmission, so
 * we can skip searching the events.
 */
- (void) setTransmitButtonStateWithHint: (BOOL) hint
{
    BOOL canTransmit = (_librariesTable.selectedRow != -1) && (_destinationsTable.selectedRow != -1);
    if (!canTransmit)
    {
        _transmitButton.enabled = NO;
    }
    else if (hint)
    {
        _transmitButton.enabled = canTransmit;
    }
    else
    {
        // Otherwise we have to inspect all of them
        for (MMLibraryEvent *event in _library.events)
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

- (void) uploadCompleted
{
    _transmitting = NO;
    [_eventsTable reloadData];
    _transmitButton.enabled = YES;
    [_progressWindowController dismiss];
}

- (void) closeTheOpenLibrary
{
    // First clean up
    for (MMPhoto *photo in _photos)
    {
        [photo close];
    }
    _photos = nil;
    [_library close];
    _library = nil;
    [_eventsTable reloadData];
    [_photosTable reloadData];
}

#pragma mark Action methods

- (IBAction) checkAllButtonWasPressed: (id) sender
{
    for (MMLibraryEvent *event in _library.events)
    {
        event.toBeProcessed = YES;
    }
    [_eventsTable reloadData];
    [self setTransmitButtonStateWithHint: YES];
}

- (IBAction) uncheckAllButtonWasPressed: (id) sender
{
    for (MMLibraryEvent *event in _library.events)
    {
        event.toBeProcessed = NO;
    }
    [_eventsTable reloadData];
    _transmitButton.enabled = NO; // Flat-out, there is no point in looking
}

- (IBAction) transmitButtonWasPressed: (id) sender
{
    if (sender == _transmitButton)
    {
        // For every combination of service and library, we maintain a destination folder.
        // Every library event will be delivered as an album within that folder. The folder itself
        // is created the first time we go through here, assigning it a name and URL fragment.
        // We preserve the nodeId, allowing the customer to rename the folder and change its URL
        // at will.
        
        // TODO This has to be cast as the right type of object. Can I just make it point to an abstract object?
        MMDestinationSmugmug *destination = [_destinationManager destinationForIndex: _destinationsTable.selectedRow];
        NSString *folderId = [destination findOrCreateFolderForLibrary: _library];
        if (!folderId)
        {
            _transmitButton.enabled = YES;
            _transmitting = NO;
// TODO Make this message more specific
            [MMUiUtility alertWithText: @"Error creating folder on service"
                          withQuestion: nil
                                 style: NSWarningAlertStyle];
            return;
        }

        // we keep a reference, so the window controller doesn't deallocate
        _progressWindowController = [MMProgressWindowController new];
        _progressWindowController.queue = _uploadOperationQueue;
        [self.window beginSheet:[_progressWindowController window]
              completionHandler: ^(NSModalResponse returnCode) {
                                       _progressWindowController = nil;
                                   }];

        // In theory, we should do this somewhere else, but in fact, it doesn't matter whether we
        // set the delegate until the button finally gets pressed.
        [_eventsTable setDelegate: self];

        _transmitButton.enabled = NO;
        _transmitting = YES;
        [_eventsTable reloadData];
        __block NSInteger row = 0;
        _totalImagesToTransmit = 0;

        for (MMLibraryEvent *event in _library.events)
        {
            if (event.toBeProcessed)
            {
                _totalImagesToTransmit += [[event filecount] integerValue];
                MMUploadOperation *uploadOperation = [[MMUploadOperation alloc] initWithEvent: event
                                                                                          row: row
                                                                                  destination: destination
                                                                                     folderId: folderId
                                                                             windowController: self];
                [_uploadOperationQueue addOperation: uploadOperation];
            }
            row++;
        }
        [self setCurrentProgressValue: 0.0];
        [self setMaxProgressValue: (Float64) _totalImagesToTransmit];
    }
}

- (IBAction) librarySegmentedControlWasPressed: (NSSegmentedControl *) segmentedControl
{
    if (segmentedControl.selectedSegment == 0) // 0 is add
    {
        [self addLibraryDialog];
    }
    else if (segmentedControl.selectedSegment == 1) // 1 is forget/delete
    {
        [self removeLibraryDialog];
    }
}

- (IBAction) destinationSegmentedControlWasPressed: (NSSegmentedControl *) segmentedControl
{
    if (segmentedControl.selectedSegment == 0) // 0 is add
    {
        [self addSmugmugDestination];
    }
    else if (segmentedControl.selectedSegment == 1) // 1 is forget/delete
    {
        [self removeDestinationDialog];
    }
}

- (IBAction) checkBoxWasChecked: (id)sender
{
    NSInteger row = [_eventsTable rowForView: sender];
    if (row >= 0)
    {
        MMLibraryEvent *event = _library.events[row];
        event.toBeProcessed = ((NSButton *)sender).state;
        [self setTransmitButtonStateWithHint: event.toBeProcessed];
    }
}

# pragma mark Actions shared between controls and menus
- (void) addLibraryDialog
{
    NSOpenPanel* dialog = [NSOpenPanel openPanel];

    // Accept file entries ending in .photolibrary or of type "package"
    [dialog setAllowedFileTypes: @[@"photolibrary", @"com.apple.package"]];
    
    // Point to the ~/Pictures (or its equivalent in some other language)
    NSArray * directories = NSSearchPathForDirectoriesInDomains(NSPicturesDirectory, NSUserDomainMask, YES);
    NSURL *url = [NSURL fileURLWithPath: [directories firstObject]];
    [dialog setDirectoryURL: url];

    // Show it as a window-modal
    [dialog beginSheetModalForWindow: self.window
                   completionHandler: ^(NSInteger result)
     {
         if (result == NSFileHandlingPanelOKButton)
         {
             // And if the user selected a file, try to open it
             NSURL *libraryUrl = [[dialog URLs] firstObject];
             MMPhotoLibrary *library = [[MMPhotoLibrary alloc] initWithPath: libraryUrl.path];

             if (library)
             {
                 [library close]; // We just need to test that it can be init'd, but we don't do a full open.
                 NSError *error;
                 NSInteger row = [_libraryManager insertLibraryPath: libraryUrl.path error: &error];
                 if (error)
                 {
                     [MMUiUtility alertWithError: error style: NSWarningAlertStyle];
                 }
                 else
                 {
                     [_librariesTable reloadData];
                     NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex: row];
                     [_librariesTable selectRowIndexes: indexSet
                                  byExtendingSelection: NO];
                 };
             }
             else
             {
                 [MMUiUtility alertWithText: @"The library could not be opened."
                               withQuestion: nil
                                      style: NSWarningAlertStyle];
             }
         }
     }
     ];
}

- (void) addFileSystemDestination
{
    // Create the File Open Dialog class.
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    // Enable the selection of files in the dialog.
    [openDlg setCanChooseFiles: NO];
    [openDlg setAllowsMultipleSelection: NO];
    [openDlg setCanChooseDirectories: YES];
    [openDlg setCanCreateDirectories: YES];
    
    // Display the dialog. If the OK button was pressed, process the files.
    if ( [openDlg runModal] == NSOKButton )
    {
        // Get the selections and then iterate over them
        NSArray* urls = [openDlg URLs];
        NSURL *url = [urls objectAtIndex: 0];
        if (url)
        {
            MMDestinationFileSystem *newDestination = [[MMDestinationFileSystem alloc] initFromDictionary: @{
                                                                                 @"type": @"filesystem",
                                                                                 @"id": [url path]
                                                                                           }];
        
            NSError *error;
            NSInteger row = [_destinationManager insertDestination: newDestination error: &error];
            [_destinationsTable reloadData];
            NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex: row];
            [_destinationsTable selectRowIndexes: indexSet
                        byExtendingSelection: NO];
        }
    }
}

- (void) addSmugmugDestination
{
    MMDestinationSmugmug *newDestination = [[MMDestinationSmugmug alloc] init];
    [newDestination authenticate: ^(BOOL success)
     {
         if (success)
         {
             NSError *error;
             NSInteger row = [_destinationManager insertDestination: newDestination error: &error];
             [_destinationsTable reloadData];
             NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex: row];
             [_destinationsTable selectRowIndexes: indexSet
                         byExtendingSelection: NO];
         }
         else
         {
             [MMUiUtility alertWithText: @"Unable to add destination."
                           withQuestion: nil
                                  style: NSWarningAlertStyle];
         }
     }];
}

- (void) removeLibraryDialog
{
    NSInteger oldSelectedRow = _librariesTable.selectedRow;
    if (oldSelectedRow > -1)
    {
        if ([MMUiUtility alertWithText: @"Stop using this library"
                          withQuestion: @"Do you want to stop using the selected library?\nYou can add it back at a later time."
                                 style: NSInformationalAlertStyle])
        {
            [_libraryManager removeLibraryAtIndex: oldSelectedRow];
            [self closeTheOpenLibrary];
            [_librariesTable reloadData];
            if (oldSelectedRow >= [_libraryManager totalLibraries])
            {
                oldSelectedRow = [_libraryManager totalLibraries] - 1;
            }
            if (oldSelectedRow >= 0)
            {
                NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex: oldSelectedRow];
                [_librariesTable selectRowIndexes: indexSet
                             byExtendingSelection: NO];
            }
        }
    }
    [self setTransmitButtonStateWithHint: NO];
}

- (void) removeDestinationDialog
{
    NSInteger oldSelectedRow = _destinationsTable.selectedRow;
    if (oldSelectedRow > -1)
    {
        if ([MMUiUtility alertWithText: @"Stop using this destination"
                          withQuestion: @"Do you want to stop using the selected destination?\nYou can add it back at a later time."
                                 style: NSInformationalAlertStyle])
        {
            [_destinationManager removeDestinationAtIndex: oldSelectedRow];
            [_destinationsTable reloadData];
            if (oldSelectedRow >= [_destinationManager totalDestinations])
            {
                oldSelectedRow = [_destinationManager totalDestinations] - 1;
            }
            if (oldSelectedRow >= 0)
            {
                NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex: oldSelectedRow];
                [_destinationsTable selectRowIndexes: indexSet
                            byExtendingSelection: NO];
            }
        }
    }
    [self setTransmitButtonStateWithHint: NO];
}

#pragma mark Proxy methods for the progress panel
/**
 * The view controller holds the panel object. This advances the progress bar.
 */
- (void) incrementProgressBy: (Float64) increment
{
    if (_progressWindowController.progressIndicator)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_progressWindowController.progressIndicator incrementBy: increment];
        });
    }
}

/**
 * Show the active photo's thumbnail in the progress sheet.
 */
- (void) setActivePhotoThumbnail: (NSImage *) photoThumbnailImage
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_progressWindowController.currentThumbnail)
        {
            _progressWindowController.currentThumbnail.image = photoThumbnailImage;
        }
    });
}

/**
 * The view controller holds the panel object. This sets the progress bar position.
 */
- (void) setCurrentProgressValue: (Float64) value
{
    if (_progressWindowController.progressIndicator)
    {
        [_progressWindowController.progressIndicator setDoubleValue: value];
    }
}

/**
 * The view controller holds the panel object. This sets the progress bar position.
 */
- (void) setMaxProgressValue: (Float64) value
{
    if (_progressWindowController.progressIndicator)
    {
        [_progressWindowController.progressIndicator setMaxValue: value];
    }
}

#pragma mark Delegate protocol methods
- (NSView *) tableView: (NSTableView *) tableView
    viewForTableColumn: (NSTableColumn *) tableColumn
                   row: (NSInteger) row
{
    NSTableCellView *baseCellView = [tableView makeViewWithIdentifier: tableColumn.identifier
                                                                owner: self];
    MMComplexTableCellView *cellView = (MMComplexTableCellView *)baseCellView;
    MMCheckboxTableCellView *checkboxCellView = (MMCheckboxTableCellView *)baseCellView;

    if (tableView == _librariesTable)
    {
        baseCellView.textField.stringValue = [_libraryManager libraryNameForIndex: row];
        baseCellView.imageView.image = _libraryIcon;
    }
    else if (tableView == _destinationsTable)
    {
        baseCellView.textField.stringValue = [_destinationManager destinationNameForIndex: row];
        baseCellView.imageView.image = _destinationIcon;
    }
    else if ((tableView == _eventsTable) && _library.events)
    {
        MMLibraryEvent *event = _library.events[row];
        if ([tableColumn.identifier isEqualToString: @"DisplayColumn"])
        {
            NSString *eventName = [event name];
            if (!eventName)
            {
                eventName = @"(none)";
            }
            cellView.firstTitleTextField.stringValue = eventName;
            if ((!cellView.firstTitleTextField.stringValue) ||
                ([cellView.firstTitleTextField.stringValue length] == 0))
            {
                cellView.firstTitleTextField.stringValue = @"(none)";
            }
            cellView.secondTextField.stringValue = [NSString stringWithFormat: @"%@ (%@)",
                                                    [event dateRange],
                                                    [event filecount]];
            cellView.imageView.image = [event getCurrentThumbnail];
            if (event.status == MMEventStatusCompleted)
            {
                cellView.iconField.image = _completedIcon;
            }
            else if (event.status == MMEventStatusActive)
            {
                // We "optimize" this update primarily so the animation doesn't start over each
                // time a photo is sent. This can cause the animation to only show the first frame or
                // two when photos are being transmitted quickly.
                if (cellView.iconField.image != _activeIcon)
                {
                    cellView.iconField.image = _activeIcon;
                }
            }
            else if (event.status == MMEventStatusIncomplete)
            {
                cellView.iconField.image = _incompleteIcon;
            }
            else
            {
                cellView.iconField.image = nil;
            }
        }
        else if ([tableColumn.identifier isEqualToString: @"CheckboxColumn"])
        {
            [checkboxCellView.checkboxField setState:event.toBeProcessed];
            [checkboxCellView.checkboxField setEnabled: !_transmitting];
        }
    }
    else if ((tableView == _photosTable) && _photos)
    {
        MMPhoto *photo = _photos[row];
        if (photo)
        {
            if ([tableColumn.identifier isEqualToString: @"NameColumn"])
            {
                NSString *name = [photo versionName];
                if (!name)
                {
                    name = @"(none)";
                }
                cellView.firstTitleTextField.stringValue = name;
                cellView.imageView.image = [photo getThumbnailImage];
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
    if (tableView == _librariesTable)
    {
        return [_libraryManager totalLibraries];
    }
    else if (tableView == _destinationsTable)
    {
        return [_destinationManager totalDestinations];
    }
    else if (tableView == _eventsTable)
    {
        return [_library.events count];
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


- (CGFloat)     splitView: (NSSplitView *) splitView
   constrainMinCoordinate:(CGFloat) proposedMin
              ofSubviewAt:(NSInteger) dividerIndex
{
    return 90.0;
}

- (CGFloat)     splitView: (NSSplitView *) splitView
   constrainMaxCoordinate: (CGFloat) proposedMin
              ofSubviewAt: (NSInteger) dividerIndex
{
    return splitView.frame.size.height - 100.0;
}

- (NSIndexSet *)            tableView: (NSTableView *) tableView
 selectionIndexesForProposedSelection: (NSIndexSet *) proposedSelectionIndexes
{
    if (proposedSelectionIndexes.count == 0)
    {
        return [tableView selectedRowIndexes];
    }
    return proposedSelectionIndexes;
}

- (void) tableViewSelectionDidChange: (NSNotification *) notification
{
    NSTableView *tableView = notification.object;
    NSInteger selectedRow = tableView.selectedRow;

    if (tableView == _librariesTable)
    {
        [self closeTheOpenLibrary];
        // Now open the library
        NSString *libraryPath = [_libraryManager libraryPathForIndex: selectedRow];
        _library = [[MMPhotoLibrary alloc] initWithPath: libraryPath];
        if (_library && [_library open])
        {
            [_eventsTable reloadData];
        }
        else
        {
            [MMUiUtility alertWithText: @"The library could not be opened."
                          withQuestion: nil
                                 style: NSWarningAlertStyle];
        }
    }
    else if (tableView == _eventsTable)
    {
        _selectedEvent = _library.events[selectedRow];
        for (MMPhoto *photo in _photos)
        {
            [photo close];
        }
        _photos = [MMPhoto getPhotosForEvent: _selectedEvent];
        [_photosTable reloadData];
    }
    [self setTransmitButtonStateWithHint: NO];
}

@end
