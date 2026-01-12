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
}

class ConversationThread {
  final String id;
  final String title;
  final DateTime startTime;
  DateTime endTime;
  final List<ConversationMessage> messages;
  final String transcriptionService; // 'Sherpa', 'Android', 'ElevenLabs'
  bool isActive;
  bool isUnread;
  
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
  }) : endTime = startTime,
       title = title ?? "Session ${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}";
}
