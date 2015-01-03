Here's how this will work:

In the library you "pull the next photo" but don't instantiate it.

Then you get the exif data and when it comes back you first instantiate the object and then update a pointer to the iPhoto object (if possible)

Look for faces.


====
RKMaster table

 uuid varchar
 name varchar
 projectUuid varchar
 alternateMasterUuid varchar << All are NULL
 originalVersionUuid varchar << Always filled in
 type varchar << IMGT (and I bet video will add a second one)
 subtype varchar << 3: JPGST, IMGST (all TIFFs!), TIFST (also TIFFs). Find out what PNGs are.
 fileIsReference integer << All are 0
 isExternallyEditable integer << Have both 0/1
 isTrulyRaw integer << Can these be handled?
 isMissing integer << What does this mean?
 hasAttachments integer <<  I have none
 hasNotes integer << I have none
 hasFocusPoints integer << NULL and 0, but in the end, I have nont
 imagePath varchar
 fileSize integer
 pixelFormat integer << 9, 15
 duration decimal << ALL are NULL, but I bet when I add a video, it works
 imageFormat integer << 3 Distinct numbers which are timestamps. 943870035 (only 1), 1246774599, 1414088262
 isInTrash integer


====

RKAdminData table
SELECT * FROM RKAdminData ORDER BY propertyArea, propertyName;
64464|database|DatabaseCompatibleBackToMinorVersion|208||5|1

56130|database|applicationIdentifier|com.apple.iPhoto||0|1

1448573|database|closedClean|1||7|0
4|database|databaseUuid|7lgzeq8DRW6hzOn5PwcOnA||0|1

56102|database|isIPhotoLibrary|1||7|1
1404214|database|loadingMastersInProgress|||20|0

1448568|database|recentVersionIds||?????@????H????X???|20|0

321888|database|versionMajor|110||5|0
321889|database|versionMinor|226||5|0

47|metadata.iPhoto|Location Version||
                                     streamtyped???@??NSNumber|20|
321891|metadata.iPhoto|Versions||
                                 streamtyped???@???NSArray|20|0

56138|touchedBy|com.apple.iPhoto|1||7|1


====
