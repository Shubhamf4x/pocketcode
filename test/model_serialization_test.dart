import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcode/models/chat_message.dart';
import 'package:pocketcode/models/conversation.dart';
import 'package:pocketcode/models/provider_config.dart';

void main() {
  test('provider round trip keeps protocol and manual models', () {
    const original = ProviderConfig(id: 'p', name: 'Local', baseUrl: 'http://localhost:8080/v1', protocol: ProviderProtocol.openAiCompatible, models: ['one', 'two'], allowInsecureHttp: true, activeModel: 'two');
    final restored = ProviderConfig.fromJson(original.toJson());
    expect(restored.toJson(), original.toJson());
  });

  test('conversation round trip keeps message statuses and controls', () {
    final original = Conversation(id: 'c', title: 'Demo', updatedAt: DateTime.utc(2025), systemPrompt: 'Be brief', temperature: 0.7, messages: [ChatMessage(id: 'm', role: MessageRole.assistant, content: 'partial', createdAt: DateTime.utc(2025), status: MessageStatus.canceled)]);
    final restored = Conversation.fromJson(original.toJson());
    expect(restored.systemPrompt, 'Be brief');
    expect(restored.temperature, 0.7);
    expect(restored.messages.single.status, MessageStatus.canceled);
  });

  test('message round trip keeps attachments', () {
    final original = ChatMessage(id: 'm', role: MessageRole.user, content: 'see this', createdAt: DateTime.utc(2025), attachments: [MessageAttachment(name: 'pic.png', mimeType: 'image/png', isImage: true, path: '/data/attachments/pic.png')]);
    final restored = ChatMessage.fromJson(original.toJson());
    expect(restored.attachments.single.name, 'pic.png');
    expect(restored.attachments.single.mimeType, 'image/png');
    expect(restored.attachments.single.isImage, isTrue);
    expect(restored.attachments.single.path, '/data/attachments/pic.png');
    expect(ChatMessage(id: 'm', role: MessageRole.user, content: 'x', createdAt: DateTime.utc(2025)).toJson().containsKey('attachments'), isFalse);
  });
}
