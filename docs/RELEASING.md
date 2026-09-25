# Releasing LRExportHEIC 2.0.0

The [release workflow](../.github/workflows/release.yml) builds the universal plug-in, signs its executable, notarizes and staples a disk image, checks the mounted contents, and creates a draft GitHub Release.
It creates the `v2.0.0` release only after the package passes those gates.
Run it from `main` after the required Apple credentials are configured.

## Required GitHub Actions secrets

- `BUILD_CERTIFICATE_BASE64`: Base64-encoded `.p12` export of a Developer ID Application certificate and its private key.
- `P12_PASSWORD`: Password for that `.p12` file.
- `NOTARY_API_KEY_BASE64`: Base64-encoded `.p8` team API key from App Store Connect.
- `NOTARY_KEY_ID`: Key ID of that team API key.
- `NOTARY_ISSUER_ID`: Issuer ID shown with the team API key.

Add these through the repository's Settings > Secrets and variables > Actions page.
Do not commit the certificate, private key, or passwords, or paste them into a GitHub issue.
An individual App Store Connect API key cannot be used with `notarytool`; create a team key.

Apple requires a Developer ID signature with hardened runtime and a secure timestamp for notarization.
The workflow fails before building if any secret is missing, and it creates no release unless notarization succeeds.

## Publish

1. Confirm the `main` CI run is green and the change log and release notes match the intended version.
2. In GitHub Actions, open **Release v2.0.0**, choose **Run workflow**, and select `main`.
3. Confirm the workflow creates a draft `v2.0.0` release with `LRExportHEIC-v2.0.0.dmg` and its SHA-256 checksum.
4. Download that draft disk image on a clean Mac, follow `INSTALLATION.txt`, and verify one Lightroom export and the capture date in Apple Photos.
5. Publish the verified draft release and send its link to users.

The signed download removes the need for each user to install Xcode or build the plug-in.
The known `.jpg` filename limitation is stated in the release notes and the disk image instructions.

## References

- [Apple: creating distribution-signed code](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac/)
- [Apple: customizing the notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
- [GitHub: installing an Apple certificate on macOS runners](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)
