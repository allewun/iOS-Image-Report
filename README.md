# iOS Image Report

Find issues in an Xcode iOS project regarding retina/non-retina, unused, and missing images.

<img src="https://raw.github.com/allewun/iOS-Image-Report/master/iOSImageReport.png" />

## Introduction
When developing for iOS, it's common to have multiple versions of the same image, one each for retina and non-retina devices (icon.png and icon@2x.png, for example).

Within the source code, the images may be referenced by either the 1x or the 2x filenames, which can have some unexpected consequences.

Running this ruby script on your Xcode project will find some of these issues in addition to missing and unused images.

## Details
Listed below are the conditions that will be checked:

* Only the 1x image exists
  * Code references 1x image => Warning: Image will be upscaled on retina devices.
  * Code references 2x image => Error: Missing image.
* Only the 2x image exists
  * Code references 1x image => [Need to check]
  * Code references 2x image => [Need to check]
* Both 1x and 2x images exist
  * Code references 1x image => Warning: Image will be downscaled on non-retina devices.

## Limitations
The current version has a few limitation:

* Only checks .png images
* Only works for a single directory