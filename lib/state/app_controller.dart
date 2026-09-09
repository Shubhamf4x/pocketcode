import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/provider_config.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../utils/endpoint_utils.dart';

class AppController extends ChangeNotifier {
  AppController(this.storage, {ApiClient? apiClient}) : api = apiClient ?? const ApiClient();

  static const _maxConversations = 200;
  static const _flushInterval = Duration(milliseconds: 60);

  final StorageService storage;
  final ApiClient api;

  List<ProviderConfig> providers = <ProviderConfig>[];
  List<Conversation> conversations = <Conversation>[];
  String? activeProviderId;
  String? activeModel;
  String? activeConversationId;
  bool ready = false;
  bool sending = false;
  String? errorMessage;

  StreamSubscription<ChatDelta>? _subscription;
  Completer<void>? _streamDone;
  bool _cancelRequested = false;
  String? _assistantId;
  bool _disposed = false;
  Timer? _flushTimer;
  Timer? _persistTimer;
  final StringBuffer _pendingText = StringBuffer();

  ProviderConfig? get activeProvider {
    final id = activeProviderId;
    if (id == null) return null;
    for (final provider in providers) {
      if (provider.id == id) return provider;
    }
    return null;
  }

  Conversation? get activeConversation {
    final id = activeConversationId;
    if (id == null) return null;
    for (final conversation in conversations) {
      if (conversation.id == id) return conversation;
    }
    return null;
  }

  Future<void> initialize() async {
    try {
      providers = storage.loadProviders();
      conversations = storage.loadConversations();
      if (conversations.length > _maxConversations) {
        conversations = conversations.sublist(0, _maxConversations);
      }
      activeProviderId = storage.activeProviderId;
      activeModel = storage.activeModel;
      activeConversationId = storage.activeConversationId;
      if (activeProviderId == null || !providers.any((provider) => provider.id == activeProviderId)) {
        activeProviderId = providers.isEmpty ? null : providers.first.id;
      }
      if (activeConversationId == null || !conversations.any((conversation) => conversation.id == activeConversationId)) {
        activeConversationId = conversations.isEmpty ? null : conversations.first.id;
      }
      final provider = activeProvider;
      if (activeModel == null && provider != null && provider.models.isNotEmpty) {
        activeModel = provider.activeModel ?? provider.models.first;
      }
    } catch (error) {
      errorMessage = 'Could not load saved data: $error';
      providers = <ProviderConfig>[];
      conversations = <Conversation>[];
    } finally {
      ready = true;
      _notify();
    }
  }

  Future<void> selectProvider(String id) async {
    if (sending || !providers.any((provider) => provider.id == id)) return;
    activeProviderId = id;
    final provider = activeProvider;
    if (provider != null) {
      activeModel = provider.activeModel ?? (provider.models.isEmpty ? null : provider.models.first);
    }
    await _guard(() async {
      await storage.setActiveProvider(id);
      final model = activeModel;
      if (model != null) await storage.setActiveModel(model);
    });
    _notify();
  }

  Future<void> selectModel(String model) async {
    if (sending || model.trim().isEmpty) return;
    activeModel = model;
    final provider = activeProvider;
    if (provider != null) await updateProvider(provider.copyWith(activeModel: model));
    await _guard(() => storage.setActiveModel(model));
    _notify();
  }

  Future<void> selectConversation(String id) async {
    if (sending || id == activeConversationId || !conversations.any((conversation) => conversation.id == id)) return;
    activeConversationId = id;
    await _guard(() => storage.setActiveConversation(id));
    _notify();
  }

  Future<void> addConversation() async {
    if (sending) return;
    final now = DateTime.now();
    final conversation = Conversation(
      id: _id(),
      title: 'New conversation',
      updatedAt: now,
      messages: const <ChatMessage>[],
    );
    conversations = [conversation, ...conversations];
    if (conversations.length > _maxConversations) {
      conversations = conversations.sublist(0, _maxConversations);
    }
    activeConversationId = conversation.id;
    await _persistConversations();
    await _guard(() => storage.setActiveConversation(conversation.id));
    _notify();
  }

  Future<void> updateConversationSettings({required String systemPrompt, required double temperature}) async {
    final conversation = activeConversation;
    if (sending || conversation == null) return;
    _replaceConversation(conversation.copyWith(
      systemPrompt: systemPrompt,
      temperature: temperature.clamp(0.0, 2.0),
    ));
    await _persistConversations();
    _notify();
  }

  Future<void> deleteConversation(String id) async {
    if (sending) return;
    final removed = conversations.where((conversation) => conversation.id == id).toList();
    conversations = conversations.where((conversation) => conversation.id != id).toList();
    if (activeConversationId == id) {
      activeConversationId = conversations.isEmpty ? null : conversations.first.id;
      final next = activeConversationId;
      if (next != null) await _guard(() => storage.setActiveConversation(next));
    }
    await _persistConversations();
    unawaited(_deleteAttachmentFiles(removed));
    _notify();
  }

  Future<void> renameConversation(String id, String title) async {
    if (sending) return;
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final conversation = conversations.where((item) => item.id == id).firstOrNull;
    if (conversation == null) return;
    _replaceConversation(conversation.copyWith(title: trimmed.length > 80 ? trimmed.substring(0, 80) : trimmed));
    await _persistConversations();
    _notify();
  }

  Future<void> addOrEditProvider({
    ProviderConfig? existing,
    required String name,
    required String baseUrl,
    required String apiKey,
    required ProviderProtocol protocol,
    required List<String> models,
    required bool allowInsecureHttp,
  }) async {
    final id = existing?.id ?? _id();
    final provider = ProviderConfig(
      id: id,
      name: name.trim(),
      baseUrl: baseUrl.trim(),
      protocol: protocol,
      models: models,
      allowInsecureHttp: allowInsecureHttp,
      activeModel: existing?.activeModel ?? (models.isEmpty ? null : models.first),
    );
    EndpointUtils.parseBase(provider.baseUrl, allowInsecureHttp: allowInsecureHttp);
    final index = providers.indexWhere((item) => item.id == id);
    providers = [...providers];
    if (index < 0) {
      providers.add(provider);
    } else {
      providers[index] = provider;
    }
    if (apiKey.trim().isNotEmpty || existing == null) {
      await storage.writeApiKey(id, apiKey);
    }
    await storage.saveProviders(providers);
    if (activeProviderId == null) {
      activeProviderId = id;
      activeModel = provider.activeModel;
      await _guard(() async {
        await storage.setActiveProvider(id);
        final model = activeModel;
        if (model != null) await storage.setActiveModel(model);
      });
    }
    _notify();
  }

  Future<void> updateProvider(ProviderConfig provider) async {
    final index = providers.indexWhere((item) => item.id == provider.id);
    if (index < 0) return;
    providers = [...providers]..[index] = provider;
    await _guard(() => storage.saveProviders(providers));
    _notify();
  }

  Future<void> deleteProvider(String id) async {
    if (sending) return;
    providers = providers.where((provider) => provider.id != id).toList();
    await _guard(() => storage.deleteApiKey(id));
    if (activeProviderId == id) {
      activeProviderId = providers.isEmpty ? null : providers.first.id;
      final provider = activeProvider;
      activeModel = provider?.activeModel ?? (provider?.models.isEmpty ?? true ? null : provider!.models.first);
      final next = activeProviderId;
      if (next != null) await _guard(() => storage.setActiveProvider(next));
    }
    await _guard(() => storage.saveProviders(providers));
    _notify();
  }

  Future<List<String>> discoverModels(ProviderConfig provider) async {
    final key = await storage.readApiKey(provider.id) ?? '';
    final found = await api.discoverModels(provider, apiKey: key);
    final updated = provider.copyWith(models: {...provider.models, ...found}.toList()..sort());
    await updateProvider(updated);
    return updated.models;
  }

  Future<void> sendMessage(String text, {List<MessageAttachment> attachments = const <MessageAttachment>[]}) async {
    if (sending) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty && attachments.isEmpty) return;
    final provider = activeProvider;
    final model = activeModel;
    if (provider == null || model == null || model.trim().isEmpty) {
      errorMessage = 'Choose a provider and model before sending.';
      _notify();
      return;
    }
    if (activeConversation == null) await addConversation();
    final conversation = activeConversation;
    if (conversation == null) return;

    errorMessage = null;
    sending = true;
    _cancelRequested = false;
    final user = ChatMessage(
      id: _id(),
      role: MessageRole.user,
      content: trimmed,
      createdAt: DateTime.now(),
      attachments: attachments,
    );
    final assistant = ChatMessage(
      id: _id(),
      role: MessageRole.assistant,
      content: '',
      createdAt: DateTime.now(),
      status: MessageStatus.streaming,
    );
    _assistantId = assistant.id;
    _replaceConversation(conversation.copyWith(
      title: conversation.messages.isEmpty ? _title(trimmed, attachments) : conversation.title,
      updatedAt: DateTime.now(),
      messages: [...conversation.messages, user, assistant],
    ));
    await _persistConversations();
    _notify();
    await _runStream(provider, model);
  }

  Future<void> retryLast() async {
    if (sending) return;
    final conversation = activeConversation;
    if (conversation == null) return;
    ChatMessage? lastUser;
    for (final message in conversation.messages.reversed) {
      if (message.role == MessageRole.user) {
        lastUser = message;
        break;
      }
    }
    if (lastUser == null || (lastUser.content.isEmpty && lastUser.attachments.isEmpty)) return;
    final cutoff = conversation.messages.lastIndexOf(lastUser);
    _replaceConversation(conversation.copyWith(messages: conversation.messages.sublist(0, cutoff + 1)));
    await _persistConversations();
    await _sendExistingUser();
  }

  Future<bool> editUserMessage(String messageId, String newText) async {
    if (sending) return false;
    final conversation = activeConversation;
    if (conversation == null) return false;
    final index = conversation.messages.indexWhere((message) => message.id == messageId);
    if (index < 0 || conversation.messages[index].role != MessageRole.user) return false;
    final original = conversation.messages[index];
    final trimmed = newText.trim();
    if (trimmed.isEmpty && original.attachments.isEmpty) return false;
    if (conversation.messages.take(index).any((message) => message.status == MessageStatus.streaming)) return false;

    final provider = activeProvider;
    final model = activeModel;
    if (provider == null || model == null || model.trim().isEmpty) {
      errorMessage = 'Choose a provider and model before sending.';
      _notify();
      return false;
    }

    final kept = conversation.messages.sublist(0, index);
    final editedUser = ChatMessage(
      id: _id(),
      role: MessageRole.user,
      content: trimmed,
      createdAt: DateTime.now(),
      attachments: original.attachments,
    );
    final assistant = ChatMessage(
      id: _id(),
      role: MessageRole.assistant,
      content: '',
      createdAt: DateTime.now(),
      status: MessageStatus.streaming,
    );
    _assistantId = assistant.id;
    sending = true;
    _cancelRequested = false;
    errorMessage = null;
    _replaceConversation(conversation.copyWith(
      updatedAt: DateTime.now(),
      messages: [...kept, editedUser, assistant],
    ));
    await _persistConversations();
    _notify();
    await _runStream(provider, model);
    return true;
  }

  Future<void> _sendExistingUser() async {
    final provider = activeProvider;
    final conversation = activeConversation;
    final model = activeModel;
    if (provider == null || conversation == null || model == null) return;
    sending = true;
    _cancelRequested = false;
    errorMessage = null;
    final assistant = ChatMessage(
      id: _id(),
      role: MessageRole.assistant,
      content: '',
      createdAt: DateTime.now(),
      status: MessageStatus.streaming,
    );
    _assistantId = assistant.id;
    _replaceConversation(conversation.copyWith(updatedAt: DateTime.now(), messages: [...conversation.messages, assistant]));
    _notify();
    await _runStream(provider, model);
  }

  Future<void> _runStream(ProviderConfig provider, String model) async {
    final done = Completer<void>();
    _streamDone = done;
    try {
      final key = await storage.readApiKey(provider.id) ?? '';
      if (_cancelRequested || _disposed) return;
      final conversation = activeConversation;
      if (conversation == null) return;
      final stream = api.stream(
        provider: provider,
        apiKey: key,
        model: model,
        messages: conversation.messages,
        systemPrompt: conversation.systemPrompt,
        temperature: conversation.temperature,
      );
      _subscription = stream.listen(
        (delta) {
          if (_cancelRequested || _disposed) return;
          if (delta.text.isNotEmpty) {
            _pendingText.write(delta.text);
            _flushTimer ??= Timer(_flushInterval, _flushPendingText);
          }
          if (delta.done) {
            _flushPendingText();
            _updateAssistant((message) => message.copyWith(status: MessageStatus.complete, clearError: true));
          }
        },
        onError: (Object error) {
          _flushPendingText();
          if (!_cancelRequested && !_disposed) {
            errorMessage = error.toString();
            _updateAssistant((message) => message.copyWith(
                  status: MessageStatus.error,
                  error: error.toString(),
                ));
          }
          if (!done.isCompleted) done.complete();
        },
        onDone: () {
          _flushPendingText();
          if (!_cancelRequested && !_disposed && _assistantStillStreaming) {
            _updateAssistant((message) => message.copyWith(status: MessageStatus.complete, clearError: true));
          }
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: true,
      );
      await done.future;
    } catch (error) {
      if (!_cancelRequested && !_disposed) {
        errorMessage = error.toString();
        _updateAssistant((message) => message.copyWith(status: MessageStatus.error, error: error.toString()));
      }
    } finally {
      _flushTimer?.cancel();
      _flushTimer = null;
      _pendingText.clear();
      final subscription = _subscription;
      _subscription = null;
      _streamDone = null;
      _assistantId = null;
      sending = false;
      if (subscription != null) unawaited(subscription.cancel().catchError((_) {}));
      await _persistConversations();
      _notify();
    }
  }

  void _flushPendingText() {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_pendingText.isEmpty) return;
    final chunk = _pendingText.toString();
    _pendingText.clear();
    _updateAssistant((message) => message.copyWith(content: message.content + chunk));
  }

  bool get _assistantStillStreaming {
    final conversation = activeConversation;
    final id = _assistantId;
    if (conversation == null || id == null) return false;
    for (final message in conversation.messages) {
      if (message.id == id) return message.status == MessageStatus.streaming;
    }
    return false;
  }

  Future<void> cancelGeneration() async {
    if (!sending) return;
    _cancelRequested = true;
    _flushPendingText();
    _updateAssistant((message) => message.copyWith(status: MessageStatus.canceled));
    await _persistConversations();
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel().catchError((_) {}));
    final done = _streamDone;
    if (done != null && !done.isCompleted) done.complete();
    sending = false;
    _assistantId = null;
    _notify();
  }

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    _notify();
  }

  void _updateAssistant(ChatMessage Function(ChatMessage) update) {
    final conversation = activeConversation;
    final id = _assistantId;
    if (conversation == null || id == null) return;
    var changed = false;
    final messages = <ChatMessage>[];
    for (final message in conversation.messages) {
      if (message.id == id) {
        messages.add(update(message));
        changed = true;
      } else {
        messages.add(message);
      }
    }
    if (!changed) return;
    _replaceConversation(conversation.copyWith(messages: messages, updatedAt: DateTime.now()), notify: true);
  }

  void _replaceConversation(Conversation updated, {bool notify = false}) {
    final index = conversations.indexWhere((item) => item.id == updated.id);
    if (index < 0) return;
    conversations = [...conversations]..[index] = updated;
    if (notify) _notify();
  }

  Future<void> _persistConversations() async {
    if (_disposed) return;
    if (sending) {
      _persistTimer ??= Timer(const Duration(seconds: 2), () {
        _persistTimer = null;
        unawaited(_guard(() => storage.saveConversations(conversations)));
      });
      return;
    }
    _persistTimer?.cancel();
    _persistTimer = null;
    await _guard(() => storage.saveConversations(conversations));
  }

  Future<void> _deleteAttachmentFiles(List<Conversation> removed) async {
    final stillUsed = <String>{
      for (final conversation in conversations)
        for (final message in conversation.messages)
          for (final attachment in message.attachments) attachment.path,
    };
    for (final conversation in removed) {
      for (final message in conversation.messages) {
        for (final attachment in message.attachments) {
          if (stillUsed.contains(attachment.path)) continue;
          try {
            final file = File(attachment.path);
            if (await file.exists()) await file.delete();
          } catch (_) {}
        }
      }
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      debugPrint('Storage operation failed: $error');
    }
  }

  int _idCounter = 0;

  String _id() {
    _idCounter = (_idCounter + 1) % 0x7fffffff;
    return '${DateTime.now().microsecondsSinceEpoch}-$_idCounter';
  }

  String _title(String text, List<MessageAttachment> attachments) {
    final compact = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (compact.isNotEmpty) {
      return compact.length > 36 ? compact.substring(0, 36) : compact;
    }
    if (attachments.isNotEmpty) {
      return attachments.first.isImage ? 'Image conversation' : attachments.first.name;
    }
    return 'New conversation';
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelRequested = true;
    _flushTimer?.cancel();
    _persistTimer?.cancel();
    final done = _streamDone;
    if (done != null && !done.isCompleted) done.complete();
    unawaited(_subscription?.cancel().catchError((_) {}) ?? Future<void>.value());
    _subscription = null;
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
