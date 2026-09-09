# PocketCode

PocketCode is a polished, mobile-first Flutter chat client for AI assistants. It stays deliberately focused: this app sends chat requests and renders markdown; it does **not** run a terminal, inspect/edit files, invoke tools, or autonomously execute coding tasks.

## Features

- Multiple persisted providers with add/edit/delete forms: name, API/base URL, secure API key, protocol, manual comma-separated models, and an explicit insecure-HTTP switch.
- OpenAI-compatible streaming `POST /chat/completions` and model discovery `GET /models`.
- Anthropic native streaming `POST /messages` (model discovery is manual for this protocol).
- API roots preserve paths such as `/v1`; they do not blindly append `/v1`. Pasted full `/chat/completions` or `/messages` URLs are normalized.
- UTF-8/SSE buffering handles chunk boundaries and multiline `data:` fields. Generation can be canceled; its per-request HTTP client and subscription are closed.
- Markdown rendering with fenced code blocks, persisted conversation histories, new/select/delete conversations, retry, and partial cancellation/error status.
- Per-conversation system prompt and temperature controls. Provider/conversation switching is disabled while generating.
- Image and file attachments with multimodal request support (base64 parts for both OpenAI-compatible and Anthropic protocols), processed off the UI thread.
- API keys are stored only with `flutter_secure_storage`; local histories and non-secret metadata use `shared_preferences` (not encrypted).
- Provider stream errors are sanitized so API keys are never surfaced in error text or logs.

## Bootstrap (exact)

The repository includes a hand-authored README, so use the separate setup file if a generator would overwrite it:

```bash
flutter create --platforms=android,ios --project-name pocketcode .
# If the command would overwrite this README, copy README.md and FLUTTER_SETUP.md
# somewhere safe first, then restore the hand-authored files after generation.
flutter pub get
flutter run
```

This starter was authored against Flutter >=3.27 and Dart >=3.6. Flutter/Dart are not bundled here and this source has not been compiled in this environment.

### Android internet permission and local HTTP development

Release Android builds need internet permission in `android/app/src/main/AndroidManifest.xml` inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

For a trusted local development server only, add `android:usesCleartextTraffic="true"` to the `<application>` element (or a narrowly scoped network security config). Also enable **Allow insecure HTTP** for that provider in PocketCode. HTTPS is the default and safest choice; the app refuses HTTP unless explicitly opted in.

### iOS ATS and localhost development

For production, use HTTPS. For local development, add a narrowly scoped ATS exception for the local host/port in `ios/Runner/Info.plist` (for example, a `NSAppTransportSecurity` dictionary with `NSExceptionDomains` for `localhost`; do not disable ATS globally). Enable **Allow insecure HTTP** for that provider. A physical iOS device generally cannot reach its computer at `localhost`; use the computer's LAN address and a trusted development setup instead.

## Configuration notes

- A base URL is the API root, for example `https://api.openai.com/v1`, `https://api.anthropic.com`, or `http://127.0.0.1:8080/v1` for explicitly enabled local development. A full pasted endpoint is accepted too.
- OpenAI-compatible vendors should expose the conventional `/chat/completions` and optionally `/models` shape. Anthropic uses its native `/messages` shape and `anthropic-version: 2023-06-01`.
- “Any API” is not automatic: a different protocol or response format requires a new adapter in `ApiClient`.
- Chat history is local preference storage and is not encrypted. Treat device backups and unlocked devices accordingly. Keys never enter preferences, chat JSON, or application logs.
- No default network request is made. Missing/invalid hosts and insecure URLs are rejected before sending.

## Tests

The project includes tests for multiline/chunked SSE parsing, endpoint normalization and insecure HTTP policy, provider/conversation serializers, storage corruption handling, and multimodal request bodies:

```bash
flutter test
```

## Safe setup file

`FLUTTER_SETUP.md` repeats the generator-safe bootstrap and platform notes in case `flutter create` replaces generated project files. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the module map.
