import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../models/provider_config.dart';
import '../utils/endpoint_utils.dart';
import 'sse_parser.dart';

class ChatDelta {
  const ChatDelta({this.text = '', this.done = false});

  final String text;
  final bool done;
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  const ApiClient();

  static const _connectTimeout = Duration(seconds: 45);
  static const _idleTimeout = Duration(seconds: 120);
  static const _discoveryTimeout = Duration(seconds: 20);
  static const _maxAnthropicOutputTokens = 64000;
  static const _maxAttachmentBytes = 20 * 1024 * 1024;

  Future<List<String>> discoverModels(ProviderConfig provider, {String apiKey = ''}) async {
    if (provider.protocol != ProviderProtocol.openAiCompatible) {
      throw const ApiException('Model discovery is available for OpenAI-compatible providers only.');
    }
    final client = http.Client();
    try {
      final key = apiKey.trim();
      if (key.isEmpty) throw const ApiException('No API key stored for this provider. Open Providers → Edit and re-enter the key.');
      final response = await client
          .get(EndpointUtils.modelsEndpoint(provider), headers: _headers(provider, key))
          .timeout(_discoveryTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(_errorBody(response.body, response.statusCode), statusCode: response.statusCode);
      }
      final Object? decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw const ApiException('Model discovery returned invalid JSON.');
      }
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('Model discovery returned an unexpected response shape.');
      }
      final data = decoded['data'];
      if (data is! List) throw const ApiException('Model discovery returned an unexpected response shape.');
      final models = data.whereType<Map<String, dynamic>>().map((item) => item['id']).whereType<String>().toSet().toList()..sort();
      return models;
    } on TimeoutException {
      throw const ApiException('Model discovery timed out.');
    } on SocketException {
      throw const ApiException('Network unavailable. Check your connection and the endpoint host.');
    } on HandshakeException {
      throw const ApiException('TLS handshake failed. Check the endpoint certificate or host.');
    } on http.ClientException catch (error) {
      throw ApiException('Connection failed: ${_redact(error.message)}');
    } finally {
      client.close();
    }
  }

  Stream<ChatDelta> stream({
    required ProviderConfig provider,
    required String apiKey,
    required String model,
    required List<ChatMessage> messages,
    required String systemPrompt,
    required double temperature,
  }) async* {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw const ApiException('No API key stored for this provider. Open Providers → Edit and re-enter the key.');
    }
    final preparedMessages = await _prepareMessages(messages);
    final payload = jsonEncode(_body(provider, model, preparedMessages, systemPrompt, temperature));
    final client = http.Client();
    try {
      final request = http.Request('POST', _chatUri(provider))
        ..headers.addAll({..._headers(provider, key), 'content-type': 'application/json', 'accept': 'text/event-stream'})
        ..bodyBytes = utf8.encode(payload);
      final response = await client.send(request).timeout(_connectTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString().timeout(_discoveryTimeout, onTimeout: () => '');
        throw ApiException(_errorBody(body, response.statusCode), statusCode: response.statusCode);
      }
      final anthropic = provider.protocol == ProviderProtocol.anthropic;
      await for (final event in SseEventAccumulator.fromBytes(response.stream.timeout(_idleTimeout))) {
        final data = event.data.trim();
        if (data.isEmpty) continue;
        if (data == '[DONE]') {
          yield const ChatDelta(done: true);
          continue;
        }
        final Map<String, dynamic> json;
        try {
          json = _decodeEvent(data);
        } on FormatException {
          continue;
        }
        _assertNoStreamError(json);
        yield anthropic ? _anthropicDelta(json, event.event) : _openAiDelta(json);
      }
    } on TimeoutException {
      throw const ApiException('Request timed out. Check the endpoint and network.');
    } on SocketException {
      throw const ApiException('Network unavailable. Check your connection and the endpoint host.');
    } on HandshakeException {
      throw const ApiException('TLS handshake failed. Check the endpoint certificate or host.');
    } on http.ClientException catch (error) {
      throw ApiException('Connection failed: ${_redact(error.message)}');
    } finally {
      client.close();
    }
  }

  ChatDelta _openAiDelta(Map<String, dynamic> json) {
    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) return const ChatDelta();
    final choice = choices.first;
    if (choice is! Map<String, dynamic>) return const ChatDelta();
    final delta = choice['delta'];
    final content = delta is Map<String, dynamic> ? delta['content'] : null;
    final text = content is String ? content : (content is List ? _joinTextParts(content) : '');
    return ChatDelta(text: text, done: choice['finish_reason'] != null);
  }

  ChatDelta _anthropicDelta(Map<String, dynamic> json, String? eventName) {
    final type = json['type'];
    if (type == 'message_stop' || eventName == 'message_stop') return const ChatDelta(done: true);
    final delta = json['delta'];
    if (delta is! Map<String, dynamic>) return const ChatDelta();
    final text = delta['text'];
    return ChatDelta(text: text is String ? text : '', done: delta['type'] == 'message_stop');
  }

  String _joinTextParts(List<dynamic> parts) {
    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map && part['type'] == 'text' && part['text'] is String) buffer.write(part['text']);
    }
    return buffer.toString();
  }

  Uri _chatUri(ProviderConfig provider) => provider.protocol == ProviderProtocol.anthropic
      ? EndpointUtils.messagesEndpoint(provider)
      : EndpointUtils.chatEndpoint(provider);

  Map<String, String> _headers(ProviderConfig provider, String apiKey) => provider.protocol == ProviderProtocol.anthropic
      ? {'x-api-key': apiKey, 'anthropic-version': '2023-06-01'}
      : {'authorization': 'Bearer $apiKey'};

  dynamic _messageContent(ProviderConfig provider, ChatMessage message) {
    if (message.attachments.isEmpty) return message.content;
    final anthropic = provider.protocol == ProviderProtocol.anthropic;
    final parts = <Map<String, dynamic>>[];
    if (message.content.trim().isNotEmpty) {
      parts.add({'type': 'text', 'text': message.content});
    }
    for (final attachment in message.attachments) {
      final base64Data = _encodeAttachment(attachment);
      if (base64Data == null) continue;
      if (anthropic) {
        parts.add({
          'type': attachment.isImage ? 'image' : 'document',
          'source': {'type': 'base64', 'media_type': attachment.mimeType, 'data': base64Data},
        });
      } else if (attachment.isImage) {
        parts.add({
          'type': 'image_url',
          'image_url': {'url': 'data:${attachment.mimeType};base64,$base64Data'},
        });
      } else {
        parts.add({
          'type': 'file',
          'file': {'filename': attachment.name, 'file_data': 'data:${attachment.mimeType};base64,$base64Data'},
        });
      }
    }
    if (parts.isEmpty) return message.content;
    return parts;
  }

  String? _encodeAttachment(MessageAttachment attachment) {
    if (attachment.encoded != null) return attachment.encoded;
    try {
      final file = File(attachment.path);
      if (!file.existsSync()) return null;
      if (file.lengthSync() > _maxAttachmentBytes) return null;
      final bytes = file.readAsBytesSync();
      return base64Encode(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<List<ChatMessage>> _prepareMessages(List<ChatMessage> messages) async {
    var needsWork = false;
    for (final message in messages) {
      for (final attachment in message.attachments) {
        if (attachment.encoded == null) {
          needsWork = true;
          break;
        }
      }
      if (needsWork) break;
    }
    if (!needsWork) return messages;
    final prepared = await compute(_encodeAttachmentsIsolate, [for (final message in messages) message]);
    return prepared;
  }

  static List<ChatMessage> _encodeAttachmentsIsolate(List<ChatMessage> messages) => [
        for (final message in messages)
          message.copyWith(attachments: [
            for (final attachment in message.attachments)
              attachment.encoded != null ? attachment : _encodeAttachmentStatic(attachment),
          ]),
      ];

  static MessageAttachment _encodeAttachmentStatic(MessageAttachment attachment) {
    try {
      final file = File(attachment.path);
      if (!file.existsSync()) return attachment;
      if (file.lengthSync() > 20 * 1024 * 1024) return attachment;
      return MessageAttachment(
        name: attachment.name,
        mimeType: attachment.mimeType,
        isImage: attachment.isImage,
        path: attachment.path,
        encoded: base64Encode(file.readAsBytesSync()),
      );
    } catch (_) {
      return attachment;
    }
  }

  Map<String, dynamic> _body(ProviderConfig provider, String model, List<ChatMessage> messages, String system, double temperature) {
    final context = messages
        .where((message) => message.role != MessageRole.system && message.isComplete)
        .map((message) => {'role': message.role.name, 'content': _messageContent(provider, message)})
        .where((message) => message['content'] is List || (message['content'] as String).trim().isNotEmpty)
        .toList();
    final cleanSystem = _effectiveSystem(system, model).trim();
    if (provider.protocol == ProviderProtocol.anthropic) {
      return {
        'model': model,
        'stream': true,
        'max_tokens': _maxAnthropicOutputTokens,
        'temperature': temperature.clamp(0.0, 1.0),
        if (cleanSystem.isNotEmpty) 'system': cleanSystem,
        'messages': context,
      };
    }
    return {
      'model': model,
      'stream': true,
      'temperature': temperature.clamp(0.0, 2.0),
      if (cleanSystem.isNotEmpty)
        'messages': [
          {'role': 'system', 'content': cleanSystem},
          ...context,
        ]
      else
        'messages': context,
    };
  }

  String _effectiveSystem(String userSystem, String model) {
    final trimmed = userSystem.trim();
    final identity =
        'You are $model, the AI assistant configured in the PocketCode app. When asked which model or AI you are, answer with exactly this model name: $model. Never claim a different identity, product, or company than the configured model name.';
    if (trimmed.isEmpty) return identity;
    return '$identity $trimmed';
  }

  void _assertNoStreamError(Map<String, dynamic> json) {
    final error = json['error'];
    if (error == null) return;
    final detail = error is Map ? (error['message']?.toString() ?? error.toString()) : error.toString();
    throw ApiException('Provider stream error: ${_redact(detail)}');
  }

  Map<String, dynamic> _decodeEvent(String data) {
    final decoded = jsonDecode(data);
    if (decoded is! Map<String, dynamic>) throw const FormatException('Unexpected event shape');
    return decoded;
  }

  String _redact(String value) => value
      .replaceAll(RegExp(r'sk-[A-Za-z0-9_\-]{8,}'), 'sk-***')
      .replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9._\-]+', caseSensitive: false), 'Bearer ***');

  String _errorBody(String body, int code) {
    var detail = '';
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic>) {
        final error = parsed['error'];
        final message = error is Map ? error['message'] : parsed['message'];
        if (message is String && message.isNotEmpty) detail = _redact(message);
      }
    } catch (_) {}
    if (code == 401 || code == 403) {
      return 'Unauthorized ($code): the API key was rejected by this provider.'
          '${detail.isEmpty ? '' : ' Provider says: $detail'}'
          ' Check Providers → Edit → API key, and that the protocol matches the endpoint.';
    }
    if (code == 404) {
      return 'Not found (404): the model or endpoint path does not exist. Check the base URL and model name.';
    }
    if (code == 429) {
      return 'Rate limited (429): the provider is throttling this key.${detail.isEmpty ? '' : ' Provider says: $detail'}';
    }
    if (code >= 500) {
      return 'Provider is unavailable ($code). Try again in a moment.${detail.isEmpty ? '' : ' Provider says: $detail'}';
    }
    if (detail.isNotEmpty) return 'Provider error ($code): $detail';
    return 'Provider error ($code). Check the URL, key, model, and provider logs.';
  }

  @visibleForTesting
  String errorBodyForTest(String body, int code) => _errorBody(body, code);

  @visibleForTesting
  Map<String, dynamic> bodyForTest(ProviderConfig provider, String model, List<ChatMessage> messages, String system, double temperature) =>
      _body(provider, model, messages, system, temperature);
}
