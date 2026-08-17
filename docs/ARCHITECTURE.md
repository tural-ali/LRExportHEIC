# Architecture and audit

## Overview

LRExportHEIC has two production components.

`LRPlugin/` is an Adobe Lightroom Classic SDK plug-in written in Lua.

`Sources/LRExportHEIC/` is a Swift command-line executable that uses Core Image, ImageIO, Core Graphics, CryptoKit, and PhotoKit.

No external image encoder is used.

## Export flow

1. Lightroom applies RAW development settings.
2. The Lua export filter overrides Lightroom's intermediate format to TIFF.
3. Lightroom renders an 8-bit TIFF for 8-bit HEIC or a 16-bit TIFF for 10-bit HEIC.
4. The filter launches the Swift executable for that rendition before advancing Lightroom's rendition iterator.
5. Lightroom can continue rendering upstream while the current conversion runs.
6. Core Image writes an 8-bit or 10-bit HEIC using Apple's encoder.
7. ImageIO copies the encoded HEIC container without recompressing its pixel payload and merges metadata from Lightroom's TIFF.
8. The Swift executable verifies semantic metadata tags and atomically installs the destination file.
9. PhotoKit optionally imports the completed HEIC.
10. The Lua filter reports success to Lightroom.
11. The plugin deletes its temporary TIFF only after Lightroom accepts the rendition.

## Lightroom SDK interactions

`Info.lua` registers both an `LrExportFilterProvider` and an `LrExportServiceProvider`.

`exportPresetFields` declares settings that Lightroom stores in the active export configuration and export presets.

`sectionForFilterInDialog` creates the HEIC settings panel.

`postProcessRenderedPhotos` owns the export lifecycle.

Its `filterSettings` callback forces TIFF, bit depth, and color space, then returns a plugin-owned temporary path.

`sourceRendition:waitForRender()` waits for Lightroom's edited TIFF.

`LrTasks.execute()` invokes the Swift executable with shell-quoted paths.

`renditionToSatisfy:renditionIsDone()` completes each Lightroom rendition.

## Swift interactions

`CommandLineOptions.swift` parses and validates the stable version 1 command-line interface plus new version 2 options.

`HEICExporter.swift` validates input and destination state, performs native encoding, manages size-limited quality search, and installs output atomically.

`MetadataCopier.swift` uses `CGImageDestinationCopyImageSource` to avoid a second lossy encode while merging Lightroom's metadata.

`PhotosImporter.swift` uses PhotoKit and a SHA-256 ledger to prevent repeated import of identical output bytes.

`FileLogger.swift` writes one JSONL file per process so concurrent exporters cannot corrupt each other's records.

## Metadata handling

The source of truth is the TIFF rendered by Lightroom.

ImageIO reads its `CGImageMetadata` tree and merges it into the already encoded HEIC container.

The destination preserves the encoder's ICC profile and HEIC pixel data.

The verifier requires semantic source tags to exist in the destination.

Format-specific TIFF storage tags such as compression, strip offsets, and the internal `iio:hasIIM` marker are intentionally excluded because they do not describe the photo and do not apply to HEIC.

The Lightroom 15.5 batch contained 199 to 200 source tags per image and 203 to 204 destination tags across EXIF, EXIF EX, TIFF, Dublin Core, Photoshop, Camera Raw, XMP, XMP Media Management, XMP Dynamic Media, and auxiliary namespaces.

## Concurrency and memory

The Lightroom SDK automatically fails a rendition if the filter advances its rendition iterator before producing the requested destination.

The Lua filter therefore completes conversion and calls `renditionIsDone` inside the same iterator step.

Each Swift process creates its own `CIContext` with intermediate caching disabled, which bounds memory to one conversion process per export filter invocation.

## Error handling

The Swift layer reports typed errors for missing or invalid input, existing destinations, encoder failures, metadata failures, file operations, PhotoKit authorization, Photos import, hashing, and ledger persistence.

Destination files are written through same-directory temporary files and moved into place only after encoding and metadata verification succeed.

Photos failures are logged as warnings and do not discard an otherwise successful HEIC export.

The Lua layer continues independent jobs after one conversion fails and reports each result back to Lightroom.

## Version 1 limitations found in the audit

- Swift 5.5 package manifest and a third-party CLI parsing dependency.
- Global option-validation state.
- `fatalError` during size-limited encoding.
- No explicit metadata preservation or verification.
- Serial conversion.
- No Photos integration or duplicate detection.
- No safe existing-destination policy.
- No atomic output installation.
- No structured performance or error logging.
- One skipped integration test and quality-search tests only.
- Temporary TIFF lifecycle left to Lightroom.
- Shell quoting that did not protect every valid filename.

## Remaining improvement opportunities

- Add a signed and notarized automated release pipeline for version 2.
- Add a Lightroom-controlled experiment for a post-acknowledgement `.heic` rename without causing a false export failure.
- Add real PhotoKit authorization integration tests behind an opt-in test flag.
- Add fixture assertions for exact metadata values, not only tag presence.
- Add process-level peak resident-memory collection to the benchmark harness.
- Investigate a supported Lightroom SDK design for bounded parallel conversion without advancing unfinished rendition iterator steps.
