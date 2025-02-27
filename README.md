![MarkersExtractorCLI.gif](assets/MarkersExtractorCLI.gif)

# MarkersExtractor CLI
[![Platforms - macOS](https://img.shields.io/badge/platforms-macOS-lightgrey.svg?style=flat)](https://www.apple.com/macos) [![License: MIT](http://img.shields.io/badge/license-MIT-lightgrey.svg?style=flat)](https://github.com/TheAcharya/MarkersExtractor/blob/main/LICENSE)

Marker metadata extraction and conversion tool for Final Cut Pro.

## Core Features

- Accurately extract Markers from FCP's FCPXML/FCPXMLD
- Ability to batch extract and render stills or animated GIFs based on each marker's timecode
- Ability to batch burn-in labels of each marker's metadata onto the stills or animated GIFs

## Available Extract Profiles

- Notion (CSV)
- Airtable (CSV & JSON)
- Pro Tools (MIDI)
- Cubase (MIDI)

## Table of contents

- [Installation](#Installation)
  - [Pre-compiled Binary (Recommended)](#pre-compiled-binary-recommended)
  - [From Source](#from-source)
- [Usage](#usage)
  - [macOS Gatekeeper & Notarization](#macos-gatekeeper--notarization)
  - [Examples](#examples)
  - [Intended Behaviour & Logic](#intended-behaviour--logic)
  - [Developer Library](#developer-library)
- [Featured](#featured)
- [Credits](#Credits)
- [License](#License)
- [Reporting Bugs](#reporting-bugs)
- [Contributing](#contributing)

## Installation

### Pre-compiled Binary (Recommended)

Download the latest release of the CLI universal binary [here](https://github.com/TheAcharya/MarkersExtractor/releases/download/0.2.0/markers-extractor-cli-0.2.0.zip).

### From Source

```shell
VERSION=0.2.0  # replace this with the git tag of the version you need
git clone https://github.com/TheAcharya/MarkersExtractor.git
cd MarkersExtractor
git checkout "tags/$VERSION"
swift build -c release
```

Once the build has finished, the `markers-extractor-cli` executable will be located at `.build/release/`.

## Usage

### CLI 0.2.0

```plain
$ markers-extractor-cli --help
OVERVIEW: Tool to extract markers from Final Cut Pro FCPXML(D).

https://github.com/TheAcharya/MarkersExtractor

USAGE: markers-extractor-cli [<options>] <fcpxml-path> <output-dir>

ARGUMENTS:
  <fcpxml-path>           Input FCPXML file / FCPXMLD bundle.
  <output-dir>            Output directory.

OPTIONS:
  --export-format <airtable, midi, notion>
                          Metadata export format. (default: notion)
  --enable-subframes      Enable output of timecode subframes.
  --image-format <png, jpg, gif>
                          Marker thumb image format. 'gif' is animated and
                          additional options can be specified with --gif-fps
                          and --gif-span. (default: png)
  --image-quality <0...100>
                          Image quality percent for JPG. (default: 85)
  --image-width <w>       Limit image width keeping aspect ratio.
  --image-height <h>      Limit image height keeping aspect ratio.
  --image-size-percent <1...100>
                          Limit image size to % keeping aspect ratio. (default
                          for GIF: 50)
  --gif-fps <0.1...60.0>  GIF frame rate. (default: 10.0)
  --gif-span <sec>        GIF capture span around marker. (default: 2.0)
  --id-naming-mode <projectTimecode, name, notes>
                          Marker naming mode. This affects Marker IDs and image
                          filenames. (default: projectTimecode)
  --include-outside-clip-boundaries
                          Include markers that are outside the bounds of a
                          clip. Also suppresses related log messages.
  --exclude-exclusive-roles <video, audio>
                          Exclude markers that have specified role type but
                          only if the opposite role type is absent.
  --label <id, name, type, checked, status, notes, position, clipName, clipFilename, clipDuration, videoRole, audioRole, eventName, projectName, libraryName, iconImage, imageFileName>
                          Label to overlay on thumb images. This argument can
                          be supplied more than once to apply multiple labels.
  --label-copyright <text>
                          Copyright label. Will be appended after other labels.
  --label-font <name>     Font for image labels. (default: Menlo-Regular)
  --label-font-size <pt>  Maximum font size for image labels, font size is
                          automatically reduced to fit all labels. (default: 30)
  --label-opacity <0...100>
                          Label opacity percent (default: 100)
  --label-font-color <#RRGGBB / #RGB>
                          Label font color (default: #FFF)
  --label-stroke-color <#RRGGBB / #RGB>
                          Label stroke color (default: #000)
  --label-stroke-width <w>
                          Label stroke width, 0 to disable. (default: auto)
  --label-align-horizontal <left, center, right>
                          Horizontal alignment of image labels. (default: left)
  --label-align-vertical <top, center, bottom>
                          Vertical alignment of image labels. (default: top)
  --label-hide-names      Hide names of image labels.
  --create-done-file      Create a file in output directory on successful
                          export. The filename can be customized using
                          --done-filename.
  --done-filename <done.json>
                          Done file filename. Has no effect unless
                          --create-done-file flag is also supplied. (default:
                          done.json)
  --folder-format <short, medium, long>
                          Output folder name format. (default: medium)
  --log <log>             Log file path.
  --log-level <trace, debug, info, notice, warning, error, critical>
                          Log level. (default: info)
  --quiet                 Disable log.
  --no-media              Bypass media. No thumbnails will be generated.
  --media-search-path <media-search-path>
                          Media search path. This argument can be supplied more
                          than once to use multiple paths. (default: same
                          folder as fcpxml(d))
  --version               Show the version.
  -h, --help              Show help information.
```

### macOS Gatekeeper & Notarization

After trying to run `markers-extractor-cli` for the first time, the process will be blocked by macOS's Gatekeeper, and a system dialog will appear which includes

> "markers-extractor-cli" can't be opened because the developer cannot be verified...

- To approve the process and allow `markers-extractor-cli` to run, go to System Preferences, Security & Privacy, General, and look in the bottom right corner for a button to click.
- After approving `markers-extractor-cli`, it should run successfully. 
- For more information, visit https://support.apple.com/en-us/HT202491.

### Examples

For ease of use, usage and creation of `.sh` files is **recommended**. 

1. Create a folder called **MarkersExtractor** on your Desktop.
2. Place the latest pre-compiled binary with the folder. 
3. Within that folder, create two more additional folders, **Render** and **Output**.
4. **Render** is where you place your `fcpxml(d)` and media files. Make sure your `fcpxml(d)` and media file have identical filename. **Output** is where your **Marker Data Set** will be generated.
5. Create a file using any text editor. Name script file with extension `.sh`
6. Copy and paste this syntax into the file, where **xxx** is the name of of your user directory and **zzz** is the name of your `.fcpxmld` file.

```bash
#!/bin/sh

TOOL_PATH="/Users/xxx/Desktop/MarkersExtractor/markers-extractor-cli"
FCPXML_PATH="/Users/xxx/Desktop/MarkersExtractor/Render/zzz.fcpxmld"
OUTPUT_DIR="/Users/xxx/Desktop/MarkersExtractor/Output"
ERROR_LOG="/Users/xxx/Desktop/MarkersExtractor/log.txt"

$TOOL_PATH "$FCPXML_PATH" "$OUTPUT_DIR" --export-format notion --image-format png --create-done-file --log-level debug --log $ERROR_LOG
```

7. Save the script file as `myscript.sh` within your **MarkersExtractor** folder.
8. To give execute permission to your script, open Terminal, `chmod +x /Users/xxx/Desktop/MarkersExtractor/myscript.sh`
9. To execute your script, open Terminal, `sh /Users/xxx/Desktop/MarkersExtractor/myscript.sh`
10. You can create and save multiple `.sh` files for different modes and configurations.

**PNG Mode with Labels**

```bash
#!/bin/sh

TOOL_PATH="/Users/xxx/Desktop/MarkersExtractor/markers-extractor-cli"
FCPXML_PATH="/Users/xxx/Desktop/MarkersExtractor/Render/zzz.fcpxmld"
OUTPUT_DIR="/Users/xxx/Desktop/MarkersExtractor/Output"
ERROR_LOG="/Users/xxx/Desktop/MarkersExtractor/log.txt"

$TOOL_PATH "$FCPXML_PATH" "$OUTPUT_DIR" --export-format notion --image-format png --label "name" --label "type" --label "notes" --label "position" --label-copyright "Road Runner & Coyote Productions" --label-font Menlo-Regular --label-align-horizontal left --label-font-size 30 --label-font-color E6ffff00 --label-stroke-color 003366 --label-stroke-width 3 --log-level debug --log $ERROR_LOG
```

**GIF Mode with Labels**

```bash
#!/bin/sh

TOOL_PATH="/Users/xxx/Desktop/MarkersExtractor/markers-extractor-cli"
FCPXML_PATH="/Users/xxx/Desktop/MarkersExtractor/Render/zzz.fcpxmld"
OUTPUT_DIR="/Users/xxx/Desktop/MarkersExtractor/Output"
ERROR_LOG="/Users/xxx/Desktop/MarkersExtractor/log.txt"

$TOOL_PATH "$FCPXML_PATH" "$OUTPUT_DIR" --export-format notion --image-format gif --image-size-percent 50 --create-done-file --label "name" --label "type" --label "notes" --label "position" --label-copyright "Road Runner & Coyote Productions" --label-font Menlo-Regular --label-align-horizontal left --label-font-size 20 --label-font-color ffff00 --label-stroke-color 003366 --label-stroke-width 4 --log-level debug --log $ERROR_LOG
```

**PNG Mode + Name Mode with Labels**

```bash
#!/bin/sh

TOOL_PATH="/Users/xxx/Desktop/MarkersExtractor/markers-extractor-cli"
FCPXML_PATH="/Users/xxx/Desktop/MarkersExtractor/Render/zzz.fcpxmld"
OUTPUT_DIR="/Users/xxx/Desktop/MarkersExtractor/Output"
ERROR_LOG="/Users/xxx/Desktop/MarkersExtractor/log.txt"

$TOOL_PATH "$FCPXML_PATH" "$OUTPUT_DIR" --export-format notion --image-format png --id-naming-mode name --label "name" --label "type" --label "notes" --label "position" --label-font-color ffff00 --log-level debug --log $ERROR_LOG
```

### Intended Behaviour & Logic
- If you have Markers nested deep within compound clips, multicam or Synchronize Clips, it will ignore them. The tool will only parse Markers of your main timeline.

### Developer Library

To use this package in a SwiftPM project, you need to set it up as a package dependency:

```swift
// swift-tools-version: 5.6
import PackageDescription

let package = Package(
  name: "MyPackage",
  dependencies: [
    .package(
        url: "https://github.com/TheAcharya/MarkersExtractor.git",
        from: "0.2.0"
    )
  ],
  targets: [
    .target(
      name: "MyTarget",
      dependencies: [
        .product(name: "MarkersExtractor", package: "MarkersExtractor")
      ]
    )
  ]
)
```

Check out [MarkersExtractorCLI.swift](https://github.com/TheAcharya/MarkersExtractor/blob/master/Sources/markers-extractor-cli/MarkersExtractorCLI.swift) to see how to use the main extractor class.

## Featured

- [Newsshooter](https://www.newsshooter.com/2023/01/03/markersextractor-cli-marker-metadata-extraction-conversion-tool-for-final-cut-pro/)

## Credits

Original Idea and Workflow by [Vigneswaran Rajkumar](https://twitter.com/IAmVigneswaran)

Maintained by [Steffan Andrews](https://github.com/orchetect) (0.2.0 ...)

Initial Work by [Vladilen Zhdanov](https://github.com/vzhd1701) ([0.1.0 ... 0.1.1](https://github.com/vzhd1701/MarkersExtractor))

## License

Licensed under the MIT license. See [LICENSE](https://github.com/TheAcharya/MarkersExtractor/blob/master/LICENSE) for details.

## Reporting Bugs

For bug reports, feature requests and other suggestions you can create [a new issue](https://github.com/TheAcharya/MarkersExtractor/issues) to discuss.

## Contributing

Code contributions are welcome. See [CONTRIBUTING](https://github.com/TheAcharya/MarkersExtractor/blob/master/CONTRIBUTING.md) for details before contributing.
