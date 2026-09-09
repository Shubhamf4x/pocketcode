import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketcode/models/chat_message.dart';
import 'package:pocketcode/models/provider_config.dart';
import 'package:pocketcode/services/api_client.dart';
import 'package:pocketcode/services/storage_service.dart';
import 'package:pocketcode/state/app_controller.dart';

class FakeApi extends ApiClient {
  FakeApi({this.reply = 'ok', this.holdsFirstCall = false, this.error});
  final String reply;
  final bool holdsFirstCall;
  final ApiException? error;
  int _calls = 0;

  @override
  Stream<ChatDelta> stream({
    required ProviderConfig provider,
    required String apiKey,
    required String model,
    required List<ChatMessage> messages,
    required String systemPrompt,
    required double temperature,
  }) async* {
    if (error != null) throw error!;
    _calls++;
    final call = _calls;
    if (holdsFirstCall && call == 1) {
      yield const ChatDelta(text: 'partial');
      await Completer<void>().future;
    }
    yield ChatDelta(text: call == 1 ? reply : 'ok');
    yield const ChatDelta(done: true);
  }
}

ProviderConfig _provider() => ProviderConfig(
      id: 'p1',
      name: 'Test',
      baseUrl: 'https://api.test/v1',
      protocol: ProviderProtocol.openAiCompatible,
      models: const ['m1'],
    );

Future<AppController> _readyController({ApiClient? apiClient}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await StorageService.open();
  final controller = AppController(storage, apiClient: apiClient);
  await controller.initialize();
  controller.providers = [_provider()];
  await storage.saveProviders(controller.providers);
  await storage.setActiveProvider('p1');
  controller.activeProviderId = 'p1';
  controller.activeModel = 'm1';
  await storage.setActiveModel('m1');
  await controller.addConversation();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sendMessage streams reply, completes status, and persists', () async {
    final controller = await _readyController(apiClient: FakeApi(reply: 'hello world'));
    await controller.sendMessage('hi');

    final messages = controller.activeConversation!.messages;
    expect(messages, hasLength(2));
    expect(messages[0].content, 'hi');
    expect(messages[0].status, MessageStatus.complete);
    expect(messages[1].content, 'hello world');
    expect(messages[1].status, MessageStatus.complete);
    expect(controller.sending, isFalse);
  });

  test('retryLast replaces the previous answer instead of stacking one', () async {
    final controller = await _readyController(apiClient: FakeApi(reply: 'first'));
    await controller.sendMessage('question');
    await controller.retryLast();

    final messages = controller.activeConversation!.messages;
    expect(messages, hasLength(2));
    expect(messages.where((m) => m.role == MessageRole.assistant).map((m) => m.content), ['ok']);
  });

  test('editUserMessage truncates after the edited turn and regenerates', () async {
    final controller = await _readyController(apiClient: FakeApi(reply: 'stale answer'));
    await controller.sendMessage('original');
    final conversation = controller.activeConversation!;
    final userId = conversation.messages.first.id;

    final ok = await controller.editUserMessage(userId, 'revised');
    expect(ok, isTrue);

    final messages = controller.activeConversation!.messages;
    expect(messages, hasLength(2));
    expect(messages[0].content, 'revised');
    expect(messages[1].content, 'ok');
    expect(messages[1].status, MessageStatus.complete);
  });

  test('editUserMessage rejects unknown ids and empty text', () async {
    final controller = await _readyController(apiClient: FakeApi());
    await controller.sendMessage('hi');
    expect(await controller.editUserMessage('missing', 'x'), isFalse);
    final userId = controller.activeConversation!.messages.first.id;
    expect(await controller.editUserMessage(userId, '   '), isFalse);
  });

  test('stream errors land in errorMessage and mark the assistant error', () async {
    final controller = await _readyController(apiClient: FakeApi(error: const ApiException('Provider error (401): nope')));
    await controller.sendMessage('hi');

    expect(controller.errorMessage, contains('401'));
    expect(controller.activeConversation!.messages.last.status, MessageStatus.error);
    expect(controller.sending, isFalse);
  });

  test('cancelGeneration stops the stream and persists the partial answer', () async {
    final controller = await _readyController(apiClient: FakeApi(holdsFirstCall: true));
    final firstSend = controller.sendMessage('hi');
    expect(controller.sending, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    await controller.cancelGeneration();
    final messages = controller.activeConversation!.messages;
    expect(messages.last.status, MessageStatus.canceled);
    expect(messages.last.content, 'partial');
    expect(controller.sending, isFalse);
    await firstSend;
    await controller.sendMessage('again');
    expect(controller.activeConversation!.messages.last.content, 'ok');
    expect(controller.sending, isFalse);
  });

  test('renameConversation updates and persists the title', () async {
    final controller = await _readyController(apiClient: FakeApi());
    await controller.renameConversation(controller.activeConversationId!, '  Renamed  ');
    expect(controller.activeConversation!.title, 'Renamed');

    final storage = controller.storage;
    final reloaded = AppController(storage, apiClient: FakeApi());
    await reloaded.initialize();
    expect(reloaded.conversations.first.title, 'Renamed');
  });

  test('double-send is blocked by the sending flag', () async {
    final controller = await _readyController(apiClient: FakeApi(reply: 'r'));
    final first = controller.sendMessage('one');
    final second = controller.sendMessage('two');
    await Future.wait([first, second]);

    final userMessages = controller.activeConversation!.messages.where((m) => m.role == MessageRole.user).toList();
    expect(userMessages, hasLength(1));
  });
}
