# LRExportHEIC

Native HEIC export for Adobe Lightroom Classic on macOS.

LRExportHEIC asks Lightroom to render an edited photo as an 8-bit or 16-bit TIFF, encodes it with Apple's native HEIC encoder, copies Lightroom's metadata into the HEIC container, and optionally imports the result into Apple Photos.

## Project status

Version 2 is under active development.

The Swift pipeline and a 20-image Lightroom Classic 15.5 batch have been tested on macOS 27 with Apple Silicon.

Use a backup and test your own workflow before relying on it for important exports.

## Features

- Apple's native 8-bit and 10-bit HEIC encoder.
- Lossless ImageIO container copy for EXIF, IPTC, XMP, GPS, Lightroom namespaces, and other metadata supplied by Lightroom.
- Embedded output ICC profile.
- Optional Apple Photos import through PhotoKit.
- Content-hash duplicate detection for repeated Photos imports.
- Bounded parallel conversion from Lightroom.
- Safe deletion of plugin-owned temporary TIFFs after Lightroom accepts the completed rendition.
- Atomic destination writes and explicit existing-file handling.
- Per-process JSONL logs under `~/Library/Logs/LRExportHEIC/`.
- Remembered Lightroom export settings for quality, bit depth, Photos import, cleanup, parallelism, and log level.
- Swift 6 with strict concurrency checks and no third-party runtime dependencies.

## Verified environment

- Lightroom Classic 15.5.
- macOS 27 beta.
- Xcode 27 beta and Swift 6.4.
- Universal `arm64` and `x86_64` release build.

Lightroom Classic 15.5 still supplies a `.jpg` destination name to this post-processing filter.

The produced file contains real HEIC data, including a 10-bit HEVC Main 10 image when 10-bit output is selected.

See [Known limitations](docs/KNOWN_LIMITATIONS.md) for details.

## Installation

Install or update from source with one command:

```bash
curl -fsSL https://raw.githubusercontent.com/tural-ali/LRExportHEIC/main/install.sh | /bin/bash
```

The installer builds a universal plugin with your installed Xcode and places it in Lightroom Classic's per-user Modules folder.

Restart Lightroom Classic after it finishes.

See [Installation](docs/INSTALLATION.md) for requirements, manual installation, and troubleshooting.

## Usage

1. Select photos in Lightroom Classic and open Export.
2. Under Post-Process Actions, select Export HEIC and click Insert.
3. Configure HEIC quality, color space, bit depth, Photos import, temporary-file cleanup, parallelism, and logging.
4. Keep Lightroom's Metadata section set to the fields you want exported.
5. Click Export.

Lightroom renders temporary TIFFs first.

The plugin converts them in parallel and writes HEIC data to Lightroom's requested destination paths.

## Tests

Run the suite with full Xcode because Apple's HEIC encoder needs access to system media services:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox
```

If you use Xcode beta, replace `Xcode.app` with `Xcode-beta.app`.

The automated suite covers JPEG, TIFF, 16-bit TIFF, 8-bit HEIC, 10-bit HEIC, metadata, ICC profiles, Unicode and long paths, concurrent batches, and Photos duplicate detection.

## Documentation

- [Architecture and audit](docs/ARCHITECTURE.md)
- [Installation](docs/INSTALLATION.md)
- [Migration from version 1](docs/MIGRATION.md)
- [Known limitations](docs/KNOWN_LIMITATIONS.md)
- [Changelog](CHANGELOG.md)

## Credits

LRExportHEIC was originally created by [Manu Wallner](https://github.com/milch).

Version 2 builds directly on Manu's Lightroom Lua plugin, native Swift encoder, quality-search implementation, release automation, and original project design.

The original repository is [milch/LRExportHEIC](https://github.com/milch/LRExportHEIC).

## License

MIT.

See [LICENSE](LICENSE).
