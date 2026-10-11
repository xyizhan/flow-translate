# Contributing

Use generated text, dummy API keys, and temporary storage for tests. Never commit real credentials, local preferences, personal screen recordings, reverse-engineering archives, downloaded application binaries, or debug output containing user text / local paths.

## Build

macOS 15+, Swift 6.0+, and compatible Xcode Command Line Tools are required. There are no external Swift package dependencies.

```sh
zsh scripts/verify.sh
zsh scripts/build-app.sh
```

The verification script covers core logic, gestures, OCR fixtures, context selection, learning persistence, exports, local SSE / JSON / HTTP errors, redirects, cancellation, and cache behavior. It uses generated data and a loopback HTTP server, not a real API service.

Optional checks:

```sh
# Uses generated credentials under a unique service in the login Keychain,
# then removes its own test entries. Requires an unlocked login Keychain.
zsh scripts/verify-keychain.sh

# Renders actual SwiftUI views with isolated fixture data, no visible windows.
.build/debug/FlowTranslate --render-design verification/design-preview

# Redacted source / artifact privacy checks
python3 scripts/audit-release.py
python3 scripts/audit-release.py --artifact 'dist/Flow Translate.app'
```

## Structure

- `Sources/FlowCore/`: endpoint rules, stream framing, gestures, context, scheduling, export helpers.
- `Sources/FlowTranslate/`: AppKit / SwiftUI application, OCR, translation client, Keychain, local learning store.
- `Tests/FlowCoreTests/`: executable checks (also works with Command Line Tools installations without XCTest).
- `scripts/`: verification, packaging, icon generation, and release privacy checks.
- `docs/`: setup, configuration, validation, and release instructions; screenshots use generated fixture data.

Keep UI changes accessible in both color schemes and preserve content-sized cards. Test network changes with the local mock before using a real provider. Do not weaken TLS or Keychain access controls to fix a development setup problem. Avoid resetting permissions belonging to other applications.

Open an issue for a reproducible bug or propose a pull request with the behavior change and relevant checks. State untested platforms honestly. Contributions are provided under this repository's MIT License; ensure that you have the right to contribute the code and assets.
