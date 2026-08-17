# Migration from version 1

Version 2 keeps the existing quality, size-limit, color-space, and bit-depth settings.

Existing Lightroom export presets continue to receive defaults for new settings.

## New defaults

- Apple Photos import: off.
- Delete temporary TIFFs: on.
- Log level: info.

## Behavior changes

- Metadata is explicitly copied and verified.
- Destination writes are atomic.
- The Lightroom plugin passes `--overwrite` for Lightroom's resolved destination. Standalone CLI use still rejects an existing destination unless `--overwrite` is explicitly supplied.
- Size-limit failures throw normal errors instead of terminating with `fatalError`.
- Temporary TIFFs are deleted only after successful HEIC creation and Lightroom acknowledgement.
- Each converter process writes its own log file.
- PhotoKit imports use content hashes to avoid duplicate imports of the same encoded file.

## Command-line compatibility

The version 1 interface remains supported:

```text
LRExportHEIC --input-file INPUT --quality 0.8 OUTPUT
```

Version 2 adds `--bit-depth`, `--photos-import`, `--photos-ledger`, `--overwrite`, `--log-directory`, `--log-level`, and `--lightroom-version`.
