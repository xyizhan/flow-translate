# Flow Translate

**Understand. Keep reading.** A native macOS screen translator with contextual word lookup, local OCR, compact reading cards, and a personal vocabulary notebook.

[简体中文](README.md) · [Download 0.4.0-beta.1](https://github.com/xyizhan/flow-translate/releases/tag/v0.4.0-beta.1) · [MIT License](LICENSE)

## Keep your reading in flow

<p align="center">
  <a href="docs/assets/posters/01-contextual-lookup.png"><img src="docs/assets/posters/01-contextual-lookup.png" width="32%" alt="Contextual word lookup: tap Option to understand bank as a riverbank in its sentence"></a>
  <a href="docs/assets/posters/02-region-translation.png"><img src="docs/assets/posters/02-region-translation.png" width="32%" alt="Region translation: select English in papers, technical documentation, or images and read the translation beside it"></a>
  <a href="docs/assets/posters/03-vocabulary-open-source.png"><img src="docs/assets/posters/03-vocabulary-open-source.png" width="32%" alt="Save words with their sentences, review with spaced practice, and export to Anki; open source with your choice of translation provider"></a>
</p>
<p align="center"><sub>Posters are in Chinese; click to enlarge. Illustrated windows are feature mockups. Actual app screenshots appear below.</sub></p>

| Reading scenario | Try this | What it helps with |
| --- | --- | --- |
| An unfamiliar word in an English article | Point at the word and tap left Option | Understand the meaning in its sentence, such as bank meaning a riverbank |
| A paragraph in a paper, technical document, or image | Option + drag, or Option + R | Read the translation beside the source with less copying and window switching |
| A word you want to remember | Save it with the card's star button | Keep its definition and sentence for review, or export to Anki |

**Local OCR, your choice of translation service.** API mode sends recognized text and relevant context, not screenshots. Connect DeepSeek or an OpenAI-compatible API; your key stays in macOS Keychain.

<p align="center"><a href="https://github.com/xyizhan/flow-translate/releases/tag/v0.4.0-beta.1"><strong>Download the macOS preview</strong></a> · <a href="#configure">Configure your service</a> · <a href="#use">Learn the gestures</a></p>

## Install

The first public preview supports **Apple Silicon (M1 or newer), macOS 15+**. No verified Intel, Windows, or Linux binary is provided. The application is free; API usage is billed separately by your provider. **Bring your own API key.**

1. Download `Flow-Translate-0.4.0-beta.1-macos-arm64.dmg` from the linked release. GitHub's “Source code” archives are not installers.
2. Open the DMG and drag **Flow Translate.app** into **Applications**. Eject the disk image and launch the installed copy.
3. This preview has an ad-hoc signature, **no Developer ID or Apple notarization**. If macOS blocks an unidentified developer, first attempt to open the app, then use **System Settings → Privacy & Security → Open Anyway**, only after checking the download's origin and checksum. See [Apple's instructions](https://support.apple.com/102445). Do not disable Gatekeeper or SIP.
4. Follow the in-app service → permissions → quick-start guide. The app lives in the menu bar by default; closing its main window does not quit it.

A ZIP alternative and `SHA256SUMS.txt` are included. Compare `shasum -a 256 <downloaded-file>` with the same release's checksum file. Installation cannot be guaranteed on organization-managed Macs that prohibit unnotarized software.

## Configure

The default API settings are:

| Field | Value |
| --- | --- |
| Endpoint | `https://api.deepseek.com` |
| Model | `deepseek-flash` |
| Key | Your own key from [DeepSeek](https://platform.deepseek.com/api_keys) |
| Fast mode | On (DeepSeek thinking disabled) |
| Target / alternate language | Simplified Chinese / English |

Use the model name available to your provider account if it differs. Save your key to Keychain and click **Test translation**. Next in the initial setup guide saves a supplied key. Web subscriptions do not necessarily include API credit.

Other OpenAI-compatible **Chat Completions** endpoints can be configured. Remote services require HTTPS; local servers may use HTTP. Word definitions require streaming and JSON-object output support, so not every compatible service supports all features. Only enter trusted endpoints.

**Apple Translation** needs no API key, but may download language packs. It provides sentence translation rather than full API dictionary fields.

Enable **Screen Recording** for pointer / region OCR and **Accessibility** for gestures, hover, and selected text. Quit and reopen if macOS requests it. Typed / pasted translation works without either screen permission. No system audio is recorded.

## Use

| Gesture | Action |
| --- | --- |
| Tap left Option | Look up the word under the pointer |
| Option + click / drag | Word lookup / region selection |
| Option + R | Select a screen region |
| Option + S | Translate selected text, falling back to pointer lookup |
| Option + Space | Lookup, optionally preferring selected text |
| Option + I | Type or paste text |
| Return / Shift+Return | Translate / new line |
| Escape | Cancel selection or close the active card |

Cards support copy, pronunciation, save, and pin. Search saved words, review them with spaced practice, and export CSV, Anki APKG, or a plain word list. Automatic hover and ordinary-click lookup are opt-in. Customize gestures, exclusions, languages, appearance, and startup in Settings. Settings has an English interface; some runtime messages remain Chinese.

## Compact reading cards

Warm light and dark themes adapt to the content and keep the translation beside your reading. Actual app screenshots:

<p align="center"><img src="docs/assets/lookup-light.png" width="350" alt="Actual app screenshot: light contextual translation card"> <img src="docs/assets/lookup-dark.png" width="350" alt="Actual app screenshot: dark contextual translation card"></p>

## Privacy

Screenshots are processed locally with Apple Vision. API mode sends recognized text and the relevant sentence to your selected provider, not screenshots. Keys stay in macOS Keychain. There is no bundled shared key, analytics SDK, account service, or automatic updater. Local vocabulary and the last 40 dictionary lookups are JSON files in `~/Library/Application Support/FlowTranslate/`; they have restrictive file permissions but are not encrypted databases. See [Privacy](PRIVACY.md) and [Security](SECURITY.md).

## Build and test

Requires macOS 15+ and Swift 6.0+ Command Line Tools / Xcode. No external Swift package dependencies.

```sh
xcode-select --install
git clone https://github.com/xyizhan/flow-translate.git
cd flow-translate
zsh scripts/verify.sh
zsh scripts/build-app.sh
zsh scripts/package-release.sh 0.4.0-beta.1
```

The app is built at `dist/Flow Translate.app`. Install it at a stable location before granting permissions. See [Contributing](CONTRIBUTING.md), [Release process](docs/RELEASING.md), [configuration reference](docs/CONFIGURATION.md), and [validation scope](docs/VALIDATION.md).

## Limits

This is a public preview, not a claim of universal compatibility. Complex columns, vertical CJK text, tiny fonts, protected content, and some games or remote desktops can defeat OCR. Selected-text support depends on the foreground app. The macOS 15 minimum is a deployment target, not proof that every 15.x release was tested. Intel runtime, the complete Apple language-pack flow, alternate physical modifier combinations, and real logout/login startup are not fully validated. Ad-hoc updates may require permission renewal. There is no automatic updater.

This independent project is not affiliated with Hover Translate, Apple, DeepSeek, or OpenAI. No original product binary, reverse-engineering archive, or private backend is included. Original code and geometric artwork are available under the MIT License.
