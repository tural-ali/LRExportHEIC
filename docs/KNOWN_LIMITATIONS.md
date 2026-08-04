# Known limitations

## Lightroom destination extension

Lightroom Classic 15.5 still provides a `.jpg` destination path to the export post-processing filter.

The file contains valid HEIC data and macOS identifies it as HEIC, but the filename remains `.jpg` for Lightroom compatibility.

The 10-bit test output was identified as `ISO Media, HEIF Image HEVC Main 10 Profile` with 10 bits per sample.

Do not batch-rename files during Lightroom's active export lifecycle because Lightroom checks its requested destination path.

## Metadata scope

The plugin preserves metadata that Lightroom writes into the intermediate TIFF.

Lightroom's Metadata export section still controls which metadata is supplied.

Metadata intentionally removed by Lightroom cannot be recovered by the plugin.

Format-specific TIFF storage tags are not copied because they are invalid or meaningless in HEIC.

## Photos duplicate detection

Duplicate detection is based on the SHA-256 hash of completed HEIC bytes and a local asset-identifier ledger.

The same visual image encoded with different settings has different bytes and is treated as a different asset.

If the Photos asset is deleted, the next matching export can be imported again.

## Release signing

Local development builds are ad-hoc signed by the linker.

Public release archives must be Developer ID signed and notarized before broad distribution.

## Test environment

Automated HEIC tests need access to Apple's media services.

Highly restricted process sandboxes can block the native HEIC encoder even when the application itself is not sandboxed.
