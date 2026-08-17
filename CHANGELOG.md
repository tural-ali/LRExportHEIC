# Changelog

## 2.0.0 - Unreleased

### Added

- One-line, non-root installer for building and installing the plugin into Lightroom's per-user Modules folder.
- Native metadata merge and post-write verification through ImageIO.
- Explicit 8-bit, 10-bit, and automatic bit-depth selection in the Swift CLI.
- PhotoKit import with SHA-256 duplicate detection.
- Safe temporary-TIFF cleanup after Lightroom acknowledgement.
- Per-process structured JSONL logging with timings, metadata counts, Photos results, Lightroom version, and macOS version.
- Typed errors and atomic destination installation.
- Automated coverage for JPEG, TIFF, 16-bit TIFF, HEIC bit depth, metadata, ICC profiles, Unicode paths, batches, quality search, and Photos duplicate detection.
- Architecture, installation, migration, and limitations documentation.

### Changed

- Updated the package to Swift tools version 6.
- Removed ConsoleKit and all third-party runtime dependencies.
- Replaced global option validation with a local typed command-line parser.
- Replaced crash paths in size-limited export with propagated errors.
- Updated the plugin version to 2.0.0.

### Fixed

- Shell quoting for spaces, Unicode, emoji, and apostrophes in paths.
- Concurrent log corruption by isolating log files per process.
- Lightroom false failure reports caused by deleting temporary TIFFs before Lightroom finished unwinding the post-processing callback. Cleanup now runs in a guarded deferred task after `renditionIsDone`.
- Lightroom false failure reports caused by advancing the rendition iterator before conversion completed. Each HEIC is now created and acknowledged within its own iterator step, as required by the Lightroom SDK.

### Verified

- Full automated suite passes with Xcode 27 beta and Swift 6.4.
- A 20-image Lightroom Classic 15.5 batch produced valid 10-bit HEIC files with 199 to 200 source metadata tags represented by 203 to 204 destination tags.
- Lightroom temporary TIFFs were removed after successful conversion.
- PhotoKit import completed successfully.
