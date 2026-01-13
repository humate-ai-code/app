import 'package:uuid/uuid.dart';

class ConversationMessage {
  final String id;
  final String sender; // 'User', 'System', 'Speaker A', etc.
  String text;
  final DateTime timestamp;
  final String? speakerId; // For later diarization
  
  // Audio synch
  final Duration? audioStartTime;
  final Duration? audioEndTime;

  ConversationMessage({
    required this.sender,
    required this.text,
    this.speakerId,
    this.audioStartTime,
    this.audioEndTime,
    DateTime? timestamp,
    String? id,
  }) : timestamp = timestamp ?? DateTime.now(),
       id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'speakerId': speakerId,
      'audioStartTime': audioStartTime?.inMilliseconds,
      'audioEndTime': audioEndTime?.inMilliseconds,
    };
  }

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      id: json['id'],
      sender: json['sender'],
      text: json['text'],
      timestamp: DateTime.parse(json['timestamp']),
      speakerId: json['speakerId'],
      audioStartTime: json['audioStartTime'] != null ? Duration(milliseconds: json['audioStartTime']) : null,
      audioEndTime: json['audioEndTime'] != null ? Duration(milliseconds: json['audioEndTime']) : null,
    );
  }
}

class ConversationThread {
  final String id;
  String title;
  String? summary;

  final DateTime startTime;
  DateTime endTime;
  final List<ConversationMessage> messages;
  final String transcriptionService; // 'Sherpa', 'Android', 'ElevenLabs'
  bool isActive;
  bool isUnread;
  
  // Analysis & Tasks
  final List<String> relatedTaskIds;
  String? lastAnalyzedMessageId;
  
  // Local audio file recording of the session
  String? audioFilePath;

  ConversationThread({
    required this.id,
    required this.startTime,
    required this.messages,
    String? title,
    this.transcriptionService = 'Sherpa',
    this.isActive = true,
    this.isUnread = true,
    this.audioFilePath,
    this.summary,
    List<String>? relatedTaskIds,
    this.lastAnalyzedMessageId,
  }) : endTime = startTime,
       relatedTaskIds = relatedTaskIds ?? [],
       title = title ?? "Session ${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}";

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'messages': messages.map((m) => m.toJson()).toList(),
      'transcriptionService': transcriptionService,
      'isActive': isActive,
      'isUnread': isUnread,
      'relatedTaskIds': relatedTaskIds,
      'lastAnalyzedMessageId': lastAnalyzedMessageId,
      'audioFilePath': audioFilePath,
    };
  }

  factory ConversationThread.fromJson(Map<String, dynamic> json) {
    return ConversationThread(
      id: json['id'],
      title: json['title'],
      summary: json['summary'],
      startTime: DateTime.parse(json['startTime']),
      messages: (json['messages'] as List).map((e) => ConversationMessage.fromJson(e)).toList(),
      transcriptionService: json['transcriptionService'] ?? 'Sherpa',
      isActive: json['isActive'] ?? false, // Default to false when loading from disk (not live)
      isUnread: json['isUnread'] ?? false,
      relatedTaskIds: (json['relatedTaskIds'] as List?)?.cast<String>(),
      lastAnalyzedMessageId: json['lastAnalyzedMessageId'],
      audioFilePath: json['audioFilePath'],
    )..endTime = DateTime.parse(json['endTime']);
  }
}

