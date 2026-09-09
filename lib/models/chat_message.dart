enum MessageRole { system, user, assistant }

enum MessageStatus { complete, streaming, canceled, error }

class MessageAttachment {
  const MessageAttachment({required this.name, required this.mimeType, required this.isImage, required this.path, this.encoded});

  final String name;
  final String mimeType;
  final bool isImage;
  final String path;
  final String? encoded;

  Map<String, dynamic> toJson() => {'name': name, 'mimeType': mimeType, 'isImage': isImage, 'path': path};

  factory MessageAttachment.fromJson(Map<String, dynamic> json) => MessageAttachment(
        name: json['name'] as String? ?? 'attachment',
        mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
        isImage: json['isImage'] as bool? ?? false,
        path: json['path'] as String? ?? '',
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.status = MessageStatus.complete,
    this.error,
    this.attachments = const <MessageAttachment>[],
  });

  final String id;
  final MessageRole role;
  final String content;
  final DateTime createdAt;
  final MessageStatus status;
  final String? error;
  final List<MessageAttachment> attachments;

  bool get isComplete => status == MessageStatus.complete;

  ChatMessage copyWith({
    String? content,
    MessageStatus? status,
    String? error,
    bool clearError = false,
    List<MessageAttachment>? attachments,
  }) =>
      ChatMessage(
        id: id,
        role: role,
        content: content ?? this.content,
        createdAt: createdAt,
        status: status ?? this.status,
        error: clearError ? null : (error ?? this.error),
        attachments: attachments ?? this.attachments,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        if (error != null) 'error': error,
        if (attachments.isNotEmpty) 'attachments': [for (final attachment in attachments) attachment.toJson()],
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        role: MessageRole.values.firstWhere(
          (value) => value.name == json['role'],
          orElse: () => MessageRole.user,
        ),
        content: json['content'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        status: MessageStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => MessageStatus.complete,
        ),
        error: json['error'] as String?,
        attachments: (json['attachments'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(MessageAttachment.fromJson)
            .where((attachment) => attachment.path.isNotEmpty)
            .toList(),
      );
}
