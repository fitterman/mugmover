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

@interface MMMasterViewController ()

@end

@implementation MMMasterViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
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
    if ([tableColumn.identifier isEqualToString:@"OnlyColumn"])
    {
        MMLibraryEvent * event = [_libraryEvents objectAtIndex: row];
//        cellView.imageView.image = event .thumbImage;
        cellView.firstTitleTextField.stringValue = [event name];
        if ((!cellView.firstTitleTextField.stringValue) ||
            ([cellView.firstTitleTextField.stringValue length] == 0))
        {
            cellView.firstTitleTextField.stringValue = @"(none)";
        }
        
        cellView.secondTextField.stringValue = [event dateRange];
        
        return cellView;
    }
    return cellView;
}


- (NSInteger)numberOfRowsInTableView: (NSTableView *)tableView
{
    return [_libraryEvents count];
}
@end
