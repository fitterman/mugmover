This is the source code for the mugmover project. It consists of the following
top-level directories:

  osx - The Mac OS mugmover utility code
  server - The Rails server code for core mugmover.com

From the osx directory, you may want to update the CocoaPods in use. Use the
command `rbenv local 2.0.0` to initially configure the version of Ruby you will
use. Subsequently, use the command `pod install --no-integrate` to update the
podfiles. Be sure to use this option or else the Xcode project settings will 
be clobbered. That command will regenerate the needed files and they are 
referenced via #include directives in the project .xcconfig files.




This code is a product of Dicentra LLC.

Copyright (c) 2014-2015 Dicentra LLC. All rights reserved. This copyright applies
to all source code and associated documentation that is part of this source tree,
exclusive of any components that are licensed from third parties, who retain 
their respective rights.

Mugmover is a trademark of Dicentra LLC.
