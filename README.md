ChattaKit
=========

ChattaKit is an Objective-C library that enables OS X and iOS Apps to send and receive text and instant messages.


* Build Requirements

 * Operating System: OS X 10.8 (Mountain Lion)
 * Development tools: XCode 4.4 and Command Line Tools

* Dependences

 * libxml2

* Build Instructions 

 1. Create new directory where you will be storing your project based off `ChattaKit`. Open Terminal and type: `mkdir $HOME/projects/ck_project`

 1. Change directories to your newly created folder: `cd %HOME/projects/ck_project `

 1. Clone the `ChattaKit` repo: `git clone git@github.com:crazyideas/ChattaKit.git`

 1. Open Xcode, create a new Workspace (`File -> New -> Workspace` give it a name, then save it in `$HOME/projects/ck_project `.

 1. In the Navigator, right click and selected `Add Files to...` and navigate to `$HOME/projects/ck_project/ChattaKit` then select `ChattaKit.xcodeproj` and click `Add`.

 1. Once again right click in the Navigator, this time select `New Project...` and create a new Cocoa or Cocoa Touch project. Name the project whatever you would like, but ensure that `User Automatic Reference Counting` is selected.

 1. Select the newly created project in the Navigator, then click `Build Phases` then under `Link Binary with Libraries` add `libChattaKit.a`

 1. Click on `Build Settings` then find `User Header Search Paths` and add `$(BUILT_PRODUCTS_DIR)` and select the recursive check box.

 1. At this point `ChattaKit` headers should be accessible to your project and you should be able to link and build against `ChattaKit`.
