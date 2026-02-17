class MessageModel {
  final String? id;
  final String? localId; // client-side UUID for optimistic tracking
  final String conversationId;
  final String senderId;
  final String messageType;
  final String? textContent;
  final Map<String, dynamic>? payload;
  final String? voiceUrl;
  final int? voiceDurationSeconds;
  final bool isRead;
  final DateTime? readAt;
  final DateTime? createdAt;
  final bool isOptimistic;
  final bool isFailed;

  const MessageModel({
    this.id,
    this.localId,
    required this.conversationId,
    required this.senderId,
    required this.messageType,
    this.textContent,
    this.payload,
    this.voiceUrl,
    this.voiceDurationSeconds,
    this.isRead = false,
    this.readAt,
    this.createdAt,
    this.isOptimistic = false,
    this.isFailed = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String?,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      messageType: json['message_type'] as String,
      textContent: json['text_content'] as String?,
      payload: json['payload'] as Map<String, dynamic>?,
      voiceUrl: json['voice_url'] as String?,
      voiceDurationSeconds: json['voice_duration_seconds'] as int?,
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'message_type': messageType,
      'text_content': textContent,
      'payload': payload,
      if (voiceUrl != null) 'voice_url': voiceUrl,
      if (voiceDurationSeconds != null)
        'voice_duration_seconds': voiceDurationSeconds,
    };
  }

  MessageModel copyWith({
    String? id,
    String? localId,
    bool? isOptimistic,
    bool? isFailed,
  }) {
    return MessageModel(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      conversationId: conversationId,
      senderId: senderId,
      messageType: messageType,
      textContent: textContent,
      payload: payload,
      voiceUrl: voiceUrl,
      voiceDurationSeconds: voiceDurationSeconds,
      isRead: isRead,
      readAt: readAt,
      createdAt: createdAt,
      isOptimistic: isOptimistic ?? this.isOptimistic,
      isFailed: isFailed ?? this.isFailed,
    );
  }
}
