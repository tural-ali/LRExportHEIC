# Installation

## Release installation

This method does not require Xcode.

1. Download `LRExportHEIC-v2.0.0.dmg` from the [GitHub Releases page](https://github.com/tural-ali/LRExportHEIC/releases) when the signed version 2 release is available.
2. Open the disk image and read `INSTALLATION.txt` inside it.
3. Quit Lightroom Classic.
4. In Finder, choose Go > Go to Folder and enter `~/Library/Application Support/Adobe/Lightroom/Modules/`.
5. Create the `Modules` folder inside `Lightroom` if it does not exist.
6. Copy `ExportHEIC.lrplugin` from the disk image into `Modules`, replacing the older copy if one is present.
7. Restart Lightroom Classic and confirm that Export HEIC is enabled under File > Plug-in Manager.

If Plug-in Manager also shows an older copy from a different path, remove that older entry so Lightroom uses the new copy in `Modules`.

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
