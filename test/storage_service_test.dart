import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketcode/models/chat_message.dart';
import 'package:pocketcode/models/conversation.dart';
import 'package:pocketcode/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('corrupt stored payloads are ignored instead of crashing', () async {
    SharedPreferences.setMockInitialValues({
      'providers.v1': '{not-json',
      'conversations.v1': '[broken',
    });
    final storage = await StorageService.open();
    expect(storage.loadProviders(), isEmpty);
    expect(storage.loadConversations(), isEmpty);
  });

  test('payloads with unexpected shapes are ignored', () async {
    SharedPreferences.setMockInitialValues({
      'providers.v1': '{"a":1}',
      'conversations.v1': '"just a string"',
    });
    final storage = await StorageService.open();
    expect(storage.loadProviders(), isEmpty);
    expect(storage.loadConversations(), isEmpty);
  });

  test('partial items inside a valid list are skipped', () async {
    SharedPreferences.setMockInitialValues({
      'conversations.v1': '[{"id":"ok","messages":[{"id":"m"}]}, 42, null]',
    });
    final storage = await StorageService.open();
    final conversations = storage.loadConversations();
    expect(conversations, hasLength(1));
    expect(conversations.single.id, 'ok');
    expect(conversations.single.messages.single.id, 'm');
  });

  test('active selections round trip', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.open();
    await storage.setActiveProvider('p1');
    await storage.setActiveModel('m1');
    await storage.setActiveConversation('c1');
    expect(storage.activeProviderId, 'p1');
    expect(storage.activeModel, 'm1');
    expect(storage.activeConversationId, 'c1');
  });

  test('conversation with attachment metadata round trips through storage', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.open();
    final conversation = Conversation(
      id: 'c1',
      title: 'with files',
      updatedAt: DateTime.utc(2026),
      messages: [
        ChatMessage(
          id: 'm1',
          role: MessageRole.user,
          content: '',
          createdAt: DateTime.utc(2026),
          attachments: [MessageAttachment(name: 'a.png', mimeType: 'image/png', isImage: true, path: '/x/a.png')],
        ),
      ],
    );
    await storage.saveConversations([conversation]);
    final loaded = storage.loadConversations();
    expect(loaded.single.messages.single.attachments.single.name, 'a.png');
    expect(loaded.single.messages.single.attachments.single.isImage, isTrue);
  });
}
