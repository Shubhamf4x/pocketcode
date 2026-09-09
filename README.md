# PocketCode

PocketCode is a mobile-first chat client for Android that connects to any
OpenAI-compatible or Anthropic-compatible AI API. It is a bring-your-own-key
client: you provide the endpoint and API key, and PocketCode handles streaming,
conversation management, and multimodal input in a clean, distraction-free
interface.

PocketCode is a chat client only. It does not run commands, access the
filesystem beyond user-selected attachments, or act on your behalf.

## Features

- **Any provider** — connect to OpenAI, Anthropic, OpenRouter, Groq, Ollama,
  LM Studio, or any endpoint exposing the OpenAI `chat/completions` or
  Anthropic `messages` API shape.
- **Real-time streaming** — responses render token-by-token over SSE, with
  reliable chunk-boundary and multiline event handling.
- **Multimodal input** — attach images and documents (PDF, DOCX, XLSX, TXT,
  and more) and send them as base64 parts; images render inline in chat.
- **Conversation management** — multiple saved conversations, rename, delete,
  retry failed generations, and edit-and-regenerate any message you sent.
- **Per-conversation controls** — independent system prompt and temperature
  per conversation.
- **Message actions** — long-press any message to copy, select text, or edit
  and regenerate the response.
- **Local-first storage** — conversations and settings live on-device in app
  preferences; nothing is synced or sent anywhere except the provider you
  configured.
- **Secure key storage** — API keys are stored in Android Keystore-backed
  encrypted storage and are never included in logs, error messages, or chat
  exports.

## Requirements

- An API endpoint and key from any compatible provider (OpenAI, Anthropic,
  OpenRouter, a self-hosted gateway, etc.)
- Android 5.0 (API 21) or later

## Installation

### From releases

Download the APK for your device from the
[releases page](https://github.com/Shubhamf4x/pocketcode/releases):

| Asset | Device |
|---|---|
| `pocketcode-*-arm64-v8a.apk` | Most phones (2016 and later) — recommended |
| `pocketcode-*-armeabi-v7a.apk` | Older 32-bit phones |
| `pocketcode-*-x86_64.apk` | Emulators and Intel-based devices |
| `pocketcode-*-universal.apk` | Any device |

Enable installation from unknown sources when prompted, then open the APK.

### Building from source

```bash
git clone https://github.com/Shubhamf4x/pocketcode.git
cd pocketcode
flutter pub get
flutter build apk --release --split-per-abi
```

Output APKs are written to `build/app/outputs/flutter-apk/`. The project
targets Flutter 3.27+ and Dart 3.6+.

## Getting started

1. Open **Providers** from the app bar and add a provider: name, base URL
   (e.g. `https://api.openai.com/v1`), API key, and protocol.
2. Pick a model from the dropdown — use **Discover models** to fetch the list
   automatically (OpenAI-compatible providers only), or type model IDs
   manually.
3. Start chatting. Attach images or files with the **+** button.

### Base URL notes

- The base URL is the API root; the app appends the correct resource paths.
- Pasting a full endpoint such as `.../v1/chat/completions` is normalized
  automatically.
- Plain `http://` is disabled unless explicitly enabled per provider, for
  local development endpoints only (e.g. `http://127.0.0.1:8080/v1` for a
  self-hosted model server).

## Privacy and security

- API keys are stored exclusively with `flutter_secure_storage` (Android
  Keystore-backed encryption) and are redacted from all error output.
- Conversations and attachments are stored locally on the device. Deleting a
  conversation also deletes its attachment files.
- The app makes network requests only to the provider endpoints you
  configure. No telemetry, no analytics, no third-party services.
- Attachment uploads are limited to 20 MB per file; files are encoded
  off the UI thread to keep the interface responsive.

## Architecture

A concise overview for contributors:

- `lib/models/` — JSON-serializable value objects (providers, conversations,
  messages, attachments).
- `lib/services/` — `ApiClient` (streaming HTTP + SSE parsing, protocol
  adapters for OpenAI-compatible and Anthropic shapes), `StorageService`
  (preferences and secure key storage).
- `lib/state/` — `AppController`, a single `ChangeNotifier` owning
  conversations, generation lifecycle, cancellation, and persistence.
- `lib/screens/` — chat and provider management UI.
- `lib/utils/` — endpoint URL normalization.

Only complete assistant messages are included in subsequent request contexts;
canceled or failed generations are retained locally with their status for
transparency but excluded from the API payload.

## Testing

```bash
flutter test
```

The suite covers SSE chunk-boundary and multiline parsing, endpoint
normalization, request body construction for both protocols (including
multimodal parts and identity handling), serializer round-trips, and storage
corruption resilience.

## License

See [LICENSE](LICENSE).
