#!/bin/bash

set -euo pipefail

readonly REPOSITORY_URL="${LREXPORTHEIC_REPOSITORY_URL:-https://github.com/tural-ali/LRExportHEIC.git}"
readonly REPOSITORY_REF="${LREXPORTHEIC_REF:-main}"
readonly MODULES_DIR="${LREXPORTHEIC_MODULES_DIR:-$HOME/Library/Application Support/Adobe/Lightroom/Modules}"
readonly PLUGIN_DIR="$MODULES_DIR/ExportHEIC.lrplugin"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "LRExportHEIC supports macOS only." >&2
  exit 1
fi

for command_name in git swift xcodebuild rsync; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    echo "Install full Xcode and accept its licence before running this installer." >&2
    exit 1
  fi
done

DEVELOPER_DIRECTORY="${DEVELOPER_DIR:-$(xcode-select -p)}"

if [[ ! -d "$DEVELOPER_DIRECTORY/Platforms/MacOSX.platform" ]]; then
  if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    DEVELOPER_DIRECTORY="/Applications/Xcode.app/Contents/Developer"
  elif [[ -d "/Applications/Xcode-beta.app/Contents/Developer" ]]; then
    DEVELOPER_DIRECTORY="/Applications/Xcode-beta.app/Contents/Developer"
  else
    echo "Full Xcode is required. Command Line Tools alone cannot build LRExportHEIC." >&2
    exit 1
  fi
fi

readonly DEVELOPER_DIRECTORY

readonly TEMP_ROOT="${TMPDIR:-/tmp}"
WORK_DIR="$(mktemp -d "${TEMP_ROOT%/}/LRExportHEIC.XXXXXX")"
readonly WORK_DIR
readonly STAGED_PLUGIN="$MODULES_DIR/.ExportHEIC.lrplugin.install-$$"
readonly PREVIOUS_PLUGIN="$WORK_DIR/ExportHEIC.lrplugin.previous"

cleanup() {
  case "$WORK_DIR" in
    "${TEMP_ROOT%/}"/LRExportHEIC.*)
      rm -rf -- "$WORK_DIR"
      ;;
  esac

  if [[ -d "$STAGED_PLUGIN" ]]; then
    rm -rf -- "$STAGED_PLUGIN"
  fi
}

trap cleanup EXIT

echo "Downloading LRExportHEIC..."
git clone --depth 1 --branch "$REPOSITORY_REF" "$REPOSITORY_URL" "$WORK_DIR/source"

echo "Building the universal Lightroom plugin..."
(
  cd "$WORK_DIR/source"
  export DEVELOPER_DIR="$DEVELOPER_DIRECTORY"
  ./build.sh
)

mkdir -p "$MODULES_DIR"
rsync -a --delete "$WORK_DIR/source/plugin/ExportHEIC.lrplugin/" "$STAGED_PLUGIN/"
chmod +x "$STAGED_PLUGIN/LRExportHEIC"

if [[ -e "$PLUGIN_DIR" ]]; then
  mv "$PLUGIN_DIR" "$PREVIOUS_PLUGIN"
fi

if ! mv "$STAGED_PLUGIN" "$PLUGIN_DIR"; then
  if [[ -e "$PREVIOUS_PLUGIN" ]]; then
    mv "$PREVIOUS_PLUGIN" "$PLUGIN_DIR"
  fi
  echo "Installation failed. The previous plugin was restored." >&2
  exit 1
fi

echo
echo "LRExportHEIC installed successfully:"
echo "$PLUGIN_DIR"
echo
echo "Restart Lightroom Classic, then add Export HEIC under Post-Process Actions in the Export dialog."
