import 'chat_message.dart';

class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
    this.systemPrompt = '',
    this.temperature = 0.2,
  });

  final String id;
  final String title;
  final DateTime updatedAt;
  final List<ChatMessage> messages;
  final String systemPrompt;
  final double temperature;

  Conversation copyWith({
    String? title,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
    String? systemPrompt,
    double? temperature,
  }) =>
      Conversation(
        id: id,
        title: title ?? this.title,
        updatedAt: updatedAt ?? this.updatedAt,
        messages: messages ?? this.messages,
        systemPrompt: systemPrompt ?? this.systemPrompt,
        temperature: temperature ?? this.temperature,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'updatedAt': updatedAt.toIso8601String(),
        'messages': [for (final message in messages) message.toJson()],
        'systemPrompt': systemPrompt,
        'temperature': temperature,
      };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: json['title'] as String? ?? 'New conversation',
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
        messages: (json['messages'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ChatMessage.fromJson)
            .toList(),
        systemPrompt: json['systemPrompt'] as String? ?? '',
        temperature: ((json['temperature'] as num?)?.toDouble() ?? 0.2).clamp(0.0, 2.0),
      );
}
