//
//  MMREVIEWTHIS.m
//  mugmover
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//

#import "MMREVIEWTHIS.h"

@implementation MMREVIEWTHIS

@end
/*

 //
 //  AppDelegate.swift
 //  mugmover
 //
 //  Created by Bob Fitterman on 2014-10-17
 //  Copyright (c) 2014 Dicentra LLC. All rights reserved.
 //
 
 import Cocoa
 
 
 extension Array {
 func each(block: T -> ()) -> Array<T> {
 for item in self {
 block(item)
 }
 return self
 }
 }
 
 @NSApplicationMain
 class AppDelegate: NSObject, NSApplicationDelegate
 {
 
 @IBOutlet weak var window: NSWindow!
 @IBOutlet weak var txtFirstName: NSTextField!
 @IBOutlet weak var txtLastName: NSTextField!
 @IBOutlet weak var txtFullName: NSTextField!
 
 
 var stream:FlickrPhotostream?
 
 func applicationDidFinishLaunching(aNotification: NSNotification)
 {
 
 // Insert code here to initialize your application
 stream = FlickrPhotostream(handle: "jayphillips")
 }
 
 func applicationWillTerminate(aNotification: NSNotification)
 {
 // Insert code here to tear down your application
 }
 
 
 
 @IBAction func btnConcatenate(sender: AnyObject)
 {
 txtFullName.stringValue = txtFirstName.stringValue +
 " " +
 txtLastName.stringValue
 
 stream!.makeRequest()
 
 var mechPart = Face(Point(x:0.740201956871493, y:0.130675429734594),
 Point(x:0.690542367342775, y:0.130675429734594),
 Point(x:0.690542367342775, y:0.202800071669161),
 Point(x:0.740201956871493, y:0.202800071669161),
 732, 504)
 var foo = mechPart.rotate(0.0)
 
 let iPhotoLibraryPath = //"/Users/bob/apdb/Library.apdb"
 "/Users/bob/Pictures/iPhoto Library.photolibrary/Database/Library.apdb"
 
 let db:FMDatabase = FMDatabase(path:iPhotoLibraryPath)
 db.open()
 
 let adjQuery =  "SELECT * FROM RKImageAdjustment " +
 "WHERE name IN ('RKCropOperation', 'RKStraightenCropOperation') " +
 "AND isEnabled = 1 " +
 "AND versionUuid = ? " +
 "ORDER BY adjIndex"
 
 let dashes = String(count: 40, repeatedValue: Character("-"))
 
 //        let library:iPhoto = iPhoto(dbPath: "/Users/bob/apdb/Library.apdb")
 ["D9ns03LuT%W%MoekLvf8PA",
 "Dw5JD9AdSTGekfvaDWTiOw",
 "FBCjrBy6Tyilmlh0OqIkMw",
 "HDFPI6dUT%GrblwZj4IPlA",
 "IQL0ooIaQd28P+68gA8eJA",
 "KDO+3wjZRryNFqRB86oD0w",
 "arOAfmAuT3+I4kd8OJD5qw",
 "ckjQ0TxmQjib1czdDrim6w",
 "rzSN3u39TPGSyav77Aloxg"].each { versionUuid in
 
 puts("--- processing adjustments on \(versionUuid) ---")
 let adjustment:FMResultSet? = db.executeQuery(adjQuery, withArgumentsInArray: [versionUuid])
 if adjustment == nil
 {
 println(db.lastErrorMessage())
 return
 }
 while adjustment!.next()
 {
 let operationName:String = adjustment!.stringForColumn("name")
 let blob:NSData = adjustment!.dataForColumn("data")
 
 // The blob contains a "root" element which is a serialized dictionary
 // Within the dictionary is the "inputKeys" and its value is another dictionary
 let unarchiver:NSKeyedUnarchiver = NSKeyedUnarchiver.init(forReadingWithData: blob)
 if unarchiver.containsValueForKey("root")
 {
 if let parameters:AnyObject? = unarchiver.decodeObjectForKey("root")
 {
 var parms = parameters as Dictionary<String, AnyObject>;
 var kvhash = parms["inputKeys"] as Dictionary<String, Double>
 if operationName == "RKStraightenCropOperation"
 {
 var angle = Double(kvhash["inputRotation"]!)
 puts("    ROTATE \(angle) degrees")
 }
 else if (operationName == "RKCropOperation")
 {
 var xOrigin = Double(kvhash["inputXOrigin"]!)
 var yOrigin = Double(kvhash["inputYOrigin"]!)
 var height = Double(kvhash["inputHeight"]!)
 var width = Double(kvhash["inputWidth"]!)
 if (height > 0.0) && (width > 0.0)
 {
 puts("    CROP to \(width)W x \(height)H at (\(xOrigin), \(yOrigin))")
 }
 }
 }
 }
 }
 }
 
 db.close()
 }
 
 
 }
 

*/