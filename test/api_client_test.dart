import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcode/models/chat_message.dart';
import 'package:pocketcode/models/provider_config.dart';
import 'package:pocketcode/services/api_client.dart';

ProviderConfig _provider(ProviderProtocol protocol) => ProviderConfig(
      id: 'p1',
      name: 'Test',
      baseUrl: 'https://api.test/v1',
      protocol: protocol,
      models: const ['m1'],
    );

List<dynamic> _chatMessages(Map<String, dynamic> body) =>
    (body['messages'] as List<dynamic>).where((message) => (message as Map<String, dynamic>)['role'] != 'system').toList();

void main() {
  final api = const ApiClient();

  group('request body', () {
    test('injects the configured model identity for openai-compatible providers', () {
      final body = api.bodyForTest(_provider(ProviderProtocol.openAiCompatible), 'my-model-x', const [], '   ', 0.4);
      final messages = body['messages'] as List<dynamic>;
      expect(messages, hasLength(1));
      expect(messages.first['role'], 'system');
      expect(messages.first['content'], contains('my-model-x'));
    });

    test('keeps the user system prompt alongside the identity', () {
      final body = api.bodyForTest(_provider(ProviderProtocol.openAiCompatible), 'my-model-x', const [], 'Be terse', 0.4);
      final system = (body['messages'] as List<dynamic>).first['content'] as String;
      expect(system, contains('Be terse'));
      expect(system, contains('my-model-x'));
    });

    test('anthropic system prompt carries the identity too', () {
      final body = api.bodyForTest(_provider(ProviderProtocol.anthropic), 'm1', const [], '', 0.5);
      expect(body['system'], contains('m1'));
      expect(body['stream'], true);
    });

    test('anthropic clamps temperature to 1.0', () {
      final body = api.bodyForTest(_provider(ProviderProtocol.anthropic), 'm1', const [], '', 2.0);
      expect(body['temperature'], 1.0);
      expect(body['max_tokens'], 64000);
    });

    test('openai temperature is clamped to the supported range', () {
      final body = api.bodyForTest(_provider(ProviderProtocol.openAiCompatible), 'm1', const [], '', 9.5);
      expect(body['temperature'], 2.0);
    });

    test('excludes incomplete (streaming/error) messages from context', () {
      final messages = [
        ChatMessage(id: 'u1', role: MessageRole.user, content: 'q', createdAt: DateTime(2025)),
        ChatMessage(id: 'a1', role: MessageRole.assistant, content: '', createdAt: DateTime(2025), status: MessageStatus.error),
        ChatMessage(id: 'u2', role: MessageRole.user, content: 'q2', createdAt: DateTime(2025)),
      ];
      final body = api.bodyForTest(_provider(ProviderProtocol.openAiCompatible), 'm1', messages, '', 0.4);
      expect(_chatMessages(body).map((m) => m['content']), ['q', 'q2']);
    });

    test('text-only messages keep plain string content with attachments empty', () {
      final messages = [ChatMessage(id: 'u1', role: MessageRole.user, content: 'hi', createdAt: DateTime(2025))];
      final body = api.bodyForTest(_provider(ProviderProtocol.openAiCompatible), 'm1', messages, '', 0.4);
      expect(_chatMessages(body).first['content'], 'hi');
    });

    test('blank messages are dropped from context', () {
      final messages = [
        ChatMessage(id: 'u1', role: MessageRole.user, content: '   ', createdAt: DateTime(2025)),
        ChatMessage(id: 'u2', role: MessageRole.user, content: 'real', createdAt: DateTime(2025)),
      ];
      final body = api.bodyForTest(_provider(ProviderProtocol.openAiCompatible), 'm1', messages, '', 0.4);
      expect(_chatMessages(body), hasLength(1));
      expect(_chatMessages(body).single['content'], 'real');
    });

    test('openai image attachment becomes image_url data part', () {
      final file = File('${Directory.systemTemp.createTempSync('att').path}${Platform.pathSeparator}pixel.png')..writeAsBytesSync([1, 2, 3]);
      final messages = [
        ChatMessage(id: 'u1', role: MessageRole.user, content: 'what is this?', createdAt: DateTime(2025), attachments: [MessageAttachment(name: 'pixel.png', mimeType: 'image/png', isImage: true, path: file.path)]),
      ];
      final body = api.bodyForTest(_provider(ProviderProtocol.openAiCompatible), 'm1', messages, '', 0.4);
      final content = _chatMessages(body).first['content'] as List<dynamic>;
      expect(content.first['type'], 'text');
      expect(content.first['text'], 'what is this?');
      expect(content.last['type'], 'image_url');
      expect((content.last['image_url'] as Map)['url'], startsWith('data:image/png;base64,'));
    });

    test('openai document attachment becomes file part', () {
      final file = File('${Directory.systemTemp.createTempSync('att').path}${Platform.pathSeparator}notes.pdf')..writeAsBytesSync([9, 9]);
      final messages = [
        ChatMessage(id: 'u1', role: MessageRole.user, content: '', createdAt: DateTime(2025), attachments: [MessageAttachment(name: 'notes.pdf', mimeType: 'application/pdf', isImage: false, path: file.path)]),
      ];
      final body = api.bodyForTest(_provider(ProviderProtocol.openAiCompatible), 'm1', messages, '', 0.4);
      final content = _chatMessages(body).first['content'] as List<dynamic>;
      expect(content.single['type'], 'file');
      expect((content.single['file'] as Map)['filename'], 'notes.pdf');
    });

    test('anthropic image attachment becomes base64 image source block', () {
      final file = File('${Directory.systemTemp.createTempSync('att').path}${Platform.pathSeparator}cat.jpg')..writeAsBytesSync([7]);
      final messages = [
        ChatMessage(id: 'u1', role: MessageRole.user, content: 'look', createdAt: DateTime(2025), attachments: [MessageAttachment(name: 'cat.jpg', mimeType: 'image/jpeg', isImage: true, path: file.path)]),
      ];
      final body = api.bodyForTest(_provider(ProviderProtocol.anthropic), 'm1', messages, '', 0.4);
      final content = _chatMessages(body).first['content'] as List<dynamic>;
      expect(content.last['type'], 'image');
      expect((content.last['source'] as Map)['media_type'], 'image/jpeg');
      expect((content.last['source'] as Map)['type'], 'base64');
    });

    test('missing attachment file is skipped without breaking the request', () {
      final messages = [
        ChatMessage(id: 'u1', role: MessageRole.user, content: 'hello', createdAt: DateTime(2025), attachments: [MessageAttachment(name: 'gone.png', mimeType: 'image/png', isImage: true, path: 'Z:/definitely/missing.png')]),
      ];
      final body = api.bodyForTest(_provider(ProviderProtocol.openAiCompatible), 'm1', messages, '', 0.4);
      final content = _chatMessages(body).first['content'] as List<dynamic>;
      expect(content.single['type'], 'text');
      expect(content.single['text'], 'hello');
    });
  });

  group('error body mapping', () {
    test('openai 401 shape surfaces provider message', () {
      final message = api.errorBodyForTest('{"error":{"message":"Incorrect API key","type":"invalid_request_error"}}', 401);
      expect(message, contains('Incorrect API key'));
      expect(message, contains('401'));
    });

    test('api keys inside provider errors are redacted', () {
      final message = api.errorBodyForTest('{"error":{"message":"Invalid key sk-abcd1234efgh5678 supplied"}}', 401);
      expect(message, contains('sk-***'));
      expect(message, isNot(contains('abcd1234efgh5678')));
    });

    test('rate limit and server errors get actionable text', () {
      expect(api.errorBodyForTest('{}', 429), contains('Rate limited'));
      expect(api.errorBodyForTest('{}', 503), contains('unavailable'));
      expect(api.errorBodyForTest('{}', 404), contains('Not found'));
    });

    test('anthropic 401 shape surfaces provider message', () {
      final message = api.errorBodyForTest('{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}', 401);
      expect(message, contains('invalid x-api-key'));
      expect(message, contains('401'));
    });

    test('non-json body falls back to generic message', () {
      expect(api.errorBodyForTest('<html>gateway</html>', 502), contains('502'));
    });
  });
}
