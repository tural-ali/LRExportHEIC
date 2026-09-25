# Installation

## Release installation

This method does not require Xcode, Terminal, or an administrator password.

1. On the [GitHub Releases page](https://github.com/tural-ali/LRExportHEIC/releases), open the latest signed release and download `LRExportHEIC-v2.0.0.dmg` under **Assets**.
   Do not use the green **Code** button or the automatically generated source ZIP.
2. Double-click the downloaded `.dmg` file and leave its window open.
3. Quit Lightroom Classic.
4. In Finder, press Shift-Command-G, paste `~/Library/Application Support/Adobe/Lightroom/Modules/`, and press Return.
   If Finder says the folder does not exist, open `~/Library/Application Support/Adobe/Lightroom/` instead and create a folder named `Modules` there.
5. Drag `ExportHEIC.lrplugin` from the disk image window into `Modules`.
   If Finder asks, choose **Replace** to update the older copy.
6. Open Lightroom Classic and choose **File > Plug-in Manager**.
   Confirm **Export HEIC** is enabled and its path ends in `Lightroom/Modules/ExportHEIC.lrplugin`.
7. Select one photo, choose **File > Export**, insert **Export HEIC** under **Post-Process Actions**, and export a test image.

If Plug-in Manager also shows an older copy from a different path, remove that older entry so Lightroom uses the new copy in `Modules`.

If the plug-in is not listed, confirm the copied folder is named exactly `ExportHEIC.lrplugin` and is directly inside `Modules`, then restart Lightroom Classic.
If macOS reports a security problem opening the signed release, do not bypass the warning; report it on the repository's [Issues page](https://github.com/tural-ali/LRExportHEIC/issues).
Lightroom may give the exported HEIC file a `.jpg` name; see [Known limitations](KNOWN_LIMITATIONS.md#lightroom-destination-extension).

## Source installation

Requirements:

- macOS 13 or later.
- Lightroom Classic.
- Full Xcode with its licence accepted.
- Git and `curl`, included with macOS developer tools.

Install or update LRExportHEIC:

```bash
curl -fsSL https://raw.githubusercontent.com/tural-ali/LRExportHEIC/main/install.sh | /bin/bash
```

The installer performs these actions without `sudo`:

1. Downloads the public repository into a temporary folder.
2. Builds a universal `arm64` and `x86_64` release executable.
3. Stages the complete plugin bundle.
4. Replaces only the existing `ExportHEIC.lrplugin` bundle after the new build succeeds.
5. Installs it under `~/Library/Application Support/Adobe/Lightroom/Modules/`.

Restart Lightroom Classic after installation.

You can review [install.sh](../install.sh) before running the one-liner.

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

## Troubleshooting the one-line installer

If `xcodebuild` reports that the licence has not been accepted, run:

```bash
sudo xcodebuild -license accept
```

If Command Line Tools points at the wrong Xcode installation, select the full Xcode app:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

The installer never modifies Lightroom catalogs, original photographs, or export destinations.

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
