# Release checklist

Use a clean checkout and generated fixtures. Never copy a developer's Application Support directory, preferences, Keychain, private investigation materials, or previous distribution directory into a release.

## Verify and build

1. Update the version and build number in `Resources/Info.plist`, README links, and validation notes. Use prerelease tags until the supported platform matrix and signing requirements are satisfied.
2. Run `zsh scripts/verify.sh`. It uses generated OCR images and a loopback API server, without a live provider or real key.
3. Run `zsh scripts/verify-keychain.sh` on a development Mac with an unlocked login Keychain. This tests generated credentials under a unique service and removes only its own records.
4. Build with `zsh scripts/build-app.sh`. The host architecture is the default; `FLOW_TRANSLATE_ARCH=arm64` or `x86_64` selects an architecture. Do not advertise an architecture as tested merely because it compiled.
5. Render fixture screenshots with `.build/debug/FlowTranslate --render-design verification/design`. Check both themes, long text, short text after long text, loading and errors. Use only these generated fixtures in public screenshots.
6. Run `python3 scripts/audit-release.py` and `python3 scripts/audit-release.py --artifact 'dist/Flow Translate.app'`. Scan source and Git history with [Gitleaks](https://github.com/gitleaks/gitleaks), with redaction enabled. Inspect all included files and Git author metadata. Automated scanning cannot prove an absence of private information.

## Signing and notarization

The default build is ad-hoc signed, **not** Developer ID signed or Apple notarized. `codesign --verify` checks bundle integrity; it does not certify trust or notarization. The first public preview explicitly documents this limitation and the system's Open Anyway flow.

When a valid Developer ID Application identity is available, supply `FLOW_TRANSLATE_SIGN_IDENTITY` to the build script. It enables hardened runtime and a secure timestamp. Submit the distributable through Apple's notarization tools using a separately configured Keychain profile, staple the accepted ticket, and validate with `spctl` and `stapler`. Keep signing certificates, credentials, and profiles outside the repository. A successful signed build alone is not notarization.

Do not disable Gatekeeper or SIP, remove quarantine as a workaround, or tell users that an ad-hoc signature has passed Apple's review. Consult [Apple's notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## Package and install

```sh
zsh scripts/package-release.sh 0.4.0-beta.1
# After committing the reviewed source:
git archive --format=zip --prefix=flow-translate/ HEAD > dist/Flow-Translate-0.4.0-beta.1-source.zip
(cd dist && shasum -a 256 Flow-Translate-0.4.0-beta.1-source.zip >> SHA256SUMS.txt)
```

The script packages a metadata-clean app, an Applications shortcut and installation/license texts in the DMG. The application ZIP is an alternative. Test both archives from an empty extraction directory; verify the DMG, architecture, minimum system target, bundle signature and launch. Verify first-run behavior without importing existing keys, preferences or learning data. Check setup, settings navigation, sample cards and normal quit/restart. Real global gestures and permission grants require a separate physical-device acceptance check.

Perform an independent build from the committed source archive. Build timestamps and ad-hoc signatures can differ, so reproducible instructions do not imply bit-for-bit reproducible binaries.

## Publish

- Push the reviewed source and tag only after scans and local checks pass. Verify the macOS CI result.
- Attach the DMG, app ZIP, explicit source ZIP and `SHA256SUMS.txt` to a GitHub release. Mark the initial release as a prerelease. GitHub's automatic source archives are not app installers.
- Describe requirements, signing limitations, configuration, and the actual test environment in release notes.
- Confirm anonymous access to the public repository and release. Download the published installer independently, compare its checksum, extract it and validate the app signature. Check README image and documentation links.
- Keep release assets immutable. Correct a defective package under a new version and explain the change; do not silently replace an installed build.
