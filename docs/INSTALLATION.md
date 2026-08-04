# Installation

## Release installation

1. Download `ExportHEIC.lrplugin` from the repository's Releases page when a version 2 release is available.
2. Move it to a permanent local folder.
3. Open Lightroom Classic.
4. Choose File > Plug-in Manager.
5. Click Add and select `ExportHEIC.lrplugin`.
6. Confirm that the status says the plug-in is enabled.

## Development installation

Requirements:

- macOS 13 or later.
- Full Xcode with the licence accepted.
- Lightroom Classic.

Build a universal executable:

```bash
swift build --configuration release --arch arm64 --arch x86_64
```

Copy the release executable into a folder with this layout:

```text
ExportHEIC.lrplugin/
  ExportHEIC.lua
  Info.lua
  PluginInfoProvider.lua
  LRExportHEIC
```

Add that folder through Lightroom's Plug-in Manager.

## Apple Photos permission

Enable Import into Apple Photos in the HEIC settings panel.

macOS may ask for Photos add-only permission during the first import.

If permission is denied, open System Settings > Privacy & Security > Photos and allow LRExportHEIC or Lightroom Classic as shown by macOS.

The HEIC export remains on disk if Photos authorization or import fails.

## Logs

Logs are stored in:

```text
~/Library/Logs/LRExportHEIC/
```

Each converter process writes a separate JSONL file.

This keeps parallel batch logs valid and makes individual image timings easy to inspect.
