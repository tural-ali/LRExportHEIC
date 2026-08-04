set -eux
set -o pipefail

swift build --configuration release --arch x86_64 --arch arm64

BIN_PATH=$(swift build --configuration release --arch x86_64 --arch arm64 --show-bin-path)

mkdir -p plugin/ExportHEIC.lrplugin
rsync -a --delete ./LRPlugin/ plugin/ExportHEIC.lrplugin/
cp "$BIN_PATH/LRExportHEIC" plugin/ExportHEIC.lrplugin/LRExportHEIC

# Update the packaged version only for an exact semantic-version tag.
if GIT_VERSION=$(git describe --tags --exact-match 2>/dev/null); then
  MAJOR_VERSION=$(echo "$GIT_VERSION" | cut -f 1 -d . | tr -d 'v')
  MINOR_VERSION=$(echo "$GIT_VERSION" | cut -f 2 -d .)
  PATCH_VERSION=$(echo "$GIT_VERSION" | cut -f 3 -d .)
  BUILD_NUMBER=$(git rev-list --all --count)

  VERSION_SPEC="VERSION = { major=${MAJOR_VERSION}, minor=${MINOR_VERSION}, revision=${PATCH_VERSION}, build=${BUILD_NUMBER} },"

  sed -i '' "s/VERSION = .*/$VERSION_SPEC/" plugin/ExportHEIC.lrplugin/Info.lua
fi
