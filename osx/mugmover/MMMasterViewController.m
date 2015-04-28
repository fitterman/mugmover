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
#import "MMPhotoLibrary.h"
#import "MMPhotoLibraryManager.h"
#import "MMUiUtility.h"
#import "MMServiceManager.h"
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
        
        _activeIcon = [MMUiUtility iconImage: @"Active-128" ofType: @"gif"];
        _completedIcon = [MMUiUtility iconImage: @"Completed-128" ofType: @"png"];
        _incompleteIcon = [MMUiUtility iconImage: @"Incomplete-128" ofType: @"png"];
        _libraryIcon = [MMUiUtility iconImage: @"Library-128" ofType: @"png"];
        _serviceIcon = [MMUiUtility iconImage: @"Service-128" ofType: @"png"];
        _transmitting = NO;

        
    }
    return self;
}

- (void)viewWillLoad
{
    if([NSViewController instancesRespondToSelector:@selector(viewWillLoad)]) {
        // [super viewWillLoad];
    }
}

- (void)viewDidLoad
{
    if([NSViewController instancesRespondToSelector:@selector(viewWillLoad)]) {
        // [super viewDidLoad];
    }
    _libraryManager = [[MMPhotoLibraryManager alloc] init];
    [_librariesTable reloadData];
    _serviceManager = [[MMServiceManager alloc] initForViewController: self];
    [_servicesTable reloadData];

}

- (void)loadView
{
    BOOL ownImp = ![NSViewController instancesRespondToSelector:@selector(viewWillLoad)];
    
    if (ownImp)
    {
        [self viewWillLoad];
    }
    
    [super loadView];
    
    if(ownImp)
    {
        [self viewDidLoad];
    }
}

- (void) dealloc
{
    _uploadOperationQueue = nil;
}

/**
 * This is a major kludge. Without it, when the window is made smaller, several controls
 * do not redraw automatically, and thus can wind up outside of the window's viewable area.
 */
- (void) forceRedrawingOfControlsAutolayoutDoesNotRedrawAfterWindowResize
{
    [_checkAllButton setNeedsDisplay: YES];
    [_uncheckAllButton setNeedsDisplay: YES];
    [_transmitButton setNeedsDisplay: YES];
    [_librariesSegmentedControl setNeedsDisplay: YES];
    [_servicesSegmentedControl setNeedsDisplay: YES];
}

- (void) uploadCompleted
{
    _transmitting = NO;
    [_eventsTable reloadData];
    _transmitButton.enabled = YES;
    _interruptButton.enabled = NO;
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
    _transmitButton.enabled = YES;
}

- (IBAction) uncheckAllButtonWasPressed: (id) sender
{
    for (MMLibraryEvent *event in _library.events)
    {
        event.toBeProcessed = NO;
    }
    [_eventsTable reloadData];
    _transmitButton.enabled = NO;
}

- (IBAction) transmitButtonWasPressed: (id) sender
{
    if (sender == _transmitButton)
    {
        // In theory, we should do this somewhere else, but in fact, it doesn't matter whether we
        // set the delegate until the button finally gets pressed.
        [_eventsTable setDelegate:self];

        _transmitButton.enabled = NO;
        _transmitting = YES;
        [_eventsTable reloadData];
        NSInteger row = 0;
        _totalImagesToTransmit = 0;
        for (MMLibraryEvent *event in _library.events)
        {
            if (event.toBeProcessed)
            {
                _totalImagesToTransmit += [[event filecount] integerValue];
                NSDictionary *options = @{@"skipProcessedImages": @(_skipProcessedImageCheckbox.state)};
                MMUploadOperation *uploadOperation = [[MMUploadOperation alloc] initWithEvent: event
                                                                                          row: row
                                                                                      service: _serviceApi
                                                                                      options: options
                                                                               viewController: self];
                [_uploadOperationQueue addOperation: uploadOperation];
            }
            row++;
        }
        _progressIndicator.maxValue = (Float64) _totalImagesToTransmit;
        [_progressIndicator setDoubleValue: 0.0];
        _interruptButton.enabled = YES;
    }
}

- (IBAction)librarySegmentedControlWasPressed: (NSSegmentedControl *) segmentedControl
{
    // 0 is add
    if (segmentedControl.selectedSegment == 0)
    {
        NSOpenPanel* dialog = [NSOpenPanel openPanel];

        // Accept file entries ending in .photolibrary or of type "package"
        [dialog setAllowedFileTypes: @[@"photolibrary", @"com.apple.package"]];
        
        // Point to the ~/Pictures (or its equivalent in some other language)
        NSArray * directories = NSSearchPathForDirectoriesInDomains(NSPicturesDirectory, NSUserDomainMask, YES);
        NSURL *url = [NSURL fileURLWithPath: [directories firstObject]];
        [dialog setDirectoryURL: url];
        
        // Show it as a window-modal
        [dialog beginSheetModalForWindow:[[self view] window] completionHandler:^(NSInteger result)
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
    else if (segmentedControl.selectedSegment == 1)
    {
        NSInteger oldSelectedRow = _librariesTable.selectedRow;
        if (oldSelectedRow > -1)
        {
            [_libraryManager removeLibraryAtIndex: _librariesTable.selectedRow];
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
}

- (IBAction)serviceSegmentedControlWasPressed: (NSSegmentedControl *) segmentedControl
{
    NSLog(@"button %lu", segmentedControl.selectedSegment);

    // 0 is add
    if (segmentedControl.selectedSegment == 0)
    {
        MMSmugmug *newService = [[MMSmugmug alloc] init];
        [newService authenticate: ^(BOOL success)
            {
                if (success)
                {
                    NSError *error;
                    [_serviceManager insertService: newService error: &error];
                    [_servicesTable reloadData];
                }
                else
                {
                    [MMUiUtility alertWithText: @"Unable to add service."
                                  withQuestion: nil
                                         style: NSWarningAlertStyle];
                }
         }];
    }
    else if (segmentedControl.selectedSegment == 1)
    {
    }
}

- (IBAction) checkBoxWasChecked: (id)sender
{
    NSInteger row = [_eventsTable rowForView: sender];
    if (row >= 0)
    {
        MMLibraryEvent *event = _library.events[row];
        event.toBeProcessed = ((NSButton *)sender).state;
        
        // If the one they just clicked is a YES, then enable the transmit button
        if (event.toBeProcessed)
        {
            _transmitButton.enabled = YES;
            return;
        }
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

- (IBAction) interruptButtonWasPressed: (id) sender
{
    if (sender == _interruptButton)
    {
        [_uploadOperationQueue cancelAllOperations];
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
    else if (tableView == _servicesTable)
    {
        baseCellView.textField.stringValue = [_serviceManager serviceNameForIndex: row];
        baseCellView.imageView.image = _serviceIcon;
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
    else if (tableView == _servicesTable)
    {
        return [_serviceManager totalServices];
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
    return 70.0;
}

- (CGFloat)     splitView: (NSSplitView *) splitView
   constrainMaxCoordinate: (CGFloat) proposedMin
              ofSubviewAt: (NSInteger) dividerIndex
{
    return splitView.frame.size.height - 70.0;
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
}

@end
