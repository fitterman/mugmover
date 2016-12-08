//
//  MMServiceAbstract.h
//  mugmover
//
//  Created by Bob Fitterman on 12/7/16.
//  Copyright © 2016 Dicentra LLC. All rights reserved.
//

#ifndef MMServiceAbstract_h
#define MMServiceAbstract_h

@class MMLibraryEvent;
@class MMPhoto;
@class MMPhotoLibrary;
@class MMUploadOperation;
@class MMWindowController;

@interface MMServiceAbstract : NSObject

@property (strong)              NSString *              accessSecret;
@property (strong)              NSString *              accessToken;
@property (strong)              MMPhoto *               currentPhoto;
@property (strong)              NSMutableArray *        errorLog;
@property (strong, readonly)    NSString *              tokenSecret;
@property (strong)              NSString *              uniqueId;

- (void) close;

- (NSString *) findOrCreateFolderForLibrary: library;

- (NSString *) identifier;

- (void) logError: (NSError *) error;

- (NSString *) name;

- (NSString *) oauthAccessToken;

- (NSString *) oauthTokenSecret;

- (NSDictionary *) serialize;

- (void) transferPhotosForEvent: (MMLibraryEvent *) event
                uploadOperation: (MMUploadOperation *) uploadOperation
               windowController: (MMWindowController *) windowController
                       folderId: (NSString *) folderId;

@end

#endif /* MMServiceAbstract_h */
