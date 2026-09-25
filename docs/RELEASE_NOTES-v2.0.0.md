# LRExportHEIC 2.0.0

This is the first version 2 download that installs without building the plug-in locally.

Download `LRExportHEIC-v2.0.0.dmg`, open it, and follow `INSTALLATION.txt` inside.

## Highlights

- Native 8-bit and 10-bit HEIC encoding with preserved Lightroom export metadata, including the original capture date when Lightroom supplies it.
- Optional import into Apple Photos with duplicate detection.
- Reliable batch completion, safe temporary TIFF cleanup, and atomic replacement of Lightroom-approved destinations.
- Per-export logs in `~/Library/Logs/LRExportHEIC/`.
- A universal Apple Silicon and Intel executable signed with Developer ID and notarized by Apple.

## Known limitation

Lightroom Classic 15.5 can give this export filter a `.jpg` destination name even though the completed file contains HEIC data.
The plug-in keeps that name because Lightroom checks its requested destination during export.
Some other applications may rely on the filename extension instead of inspecting the file content.
The file's macOS creation date is the export date; the original capture date is stored in its embedded metadata.

## Verified environment

The automated suite and universal build pass on the current GitHub CI runner.
Lightroom Classic 15.5 and macOS 27 were used for a 20-image export test.
