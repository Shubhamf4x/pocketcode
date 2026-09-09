# PocketCode architecture

PocketCode is deliberately a chat client, not an agent runtime. `HomeScreen` owns the responsive Material 3 chat UI; `ProviderScreen` handles provider CRUD. `AppController` is the single ChangeNotifier for active selections, conversations, generation state, cancellation, and persistence.

- `models/` contains JSON-safe provider, conversation, and message value objects.
- `services/storage_service.dart` keeps non-secret metadata and histories in `shared_preferences`; API keys use `flutter_secure_storage` exclusively.
- `services/api_client.dart` creates one `http.Client` per request. Its `async*` `finally` closes that client when a stream completes or is canceled. `sse_parser.dart` decodes UTF-8 before `LineSplitter` and joins multiline SSE data fields.
- `utils/endpoint_utils.dart` treats the entered URL as an API root, preserves paths such as `/v1`, and strips pasted `/chat/completions` or `/messages` suffixes. It never invents `/v1`.
- OpenAI-compatible requests use `/chat/completions` and `/models`; Anthropic requests use native `/messages` SSE. Other vendor protocols need an adapter.

Incomplete assistant output is stored with `canceled`, `error`, or `streaming` status for transparency, but only complete assistant messages are included in the next request context. Switching provider/conversation is disabled while a generation is active.
