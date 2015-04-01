# OSX


* MUST HAVE ORIGINAL TYPE if ORIGINAL NAME is captured

- Change how the image requests work. First get the sizes, then the byte size,
  and then go for the version stuff. When applying the version stuff, verify
  the image size on the query an finally the byte size.

- Track down memory leaks
- Get the requests on a background thread
- Add a generalized method to score best matches
- Upload photos
- Figure out how to detect dirty closes, iPhoto starting, etc.
- Shoot some raw photos and see what happens
- Optimize note creation to reduce the number of API calls.
- Try Aperture.
- migrate from "_foo" to self.foo (see http://stackoverflow.com/questions/14112715/self-variablename-vs-variablename-vs-sysnthesize-variablename)
- Deal with error-handling from the mugmover server


# Server
- Flickr does not always have some sizes (1024, 1600 but we assume they do).
- Our photo thumbnails are substantially worse than flickr's

URL Scheme: account/obfuscated-service-account-id


// Figure out collections (which contain Sets) and Sets (which contain phtos) and figure out how to tell what photos are in which.
// Photos can be in multiple Albums (fka Sets).

// Research tags, both in iPhoto and Flickr. Use them to suppress or categorize how uploads are treated.

# Smugmug
Each iPhoto database will map to a single folder on Smugmug. Each iPhoto event will map to a single album on Smugmug. By default, that Album will be placed inside folder for that particular database, but if the user chooses to move that Album somewhere else, that's fine: it still works (confirm). This information just needs to persist somewhere.

    // Top-level folder: https://api.smugmug.com/api/v2/folder/user/cmac
    // All albums for this user: https://api.smugmug.com/api/v2/folder/user/cmac!albumlist
    // Folders in this folder: https://api.smugmug.com/api/v2/folder/user/cmac!folderlist ?count=10&start=11
    // Albums in this folder: https://api.smugmug.com/api/v2/folder/user/cmac!albums
    // Images in an album: https://api.smugmug.com/api/v2/album/FQTm9n!images



# Data model

This is murky. There is a _Person_, _DisplayName_ but I think there needs to be another object. 

#. Introduce a _NamedFace_ object, which stores the faceUuid, faceKey, databaseUuid and the hosting service account.

#. The _NamedFace_ should be tied to a _DisplayName_ which contains the same name as the upload reports. If that requires 
#  creation of a  new object, so be it. If an existing object matches, then just use it.

Later in the process, it will be possible for a user with a login to be associated with one or more NamedFaces, for which they can control
a variety of determined factors.

