import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_app/models/conversation_model.dart';
import 'package:uuid/uuid.dart';

class ConversationRepository {
  static final ConversationRepository _instance = ConversationRepository._internal();
  factory ConversationRepository() => _instance;
  ConversationRepository._internal();

  final List<ConversationThread> _threads = [];
  ConversationThread? _activeThread;

  final _controller = StreamController<List<ConversationThread>>.broadcast();

  Stream<List<ConversationThread>> get threadsStream => _controller.stream;
  List<ConversationThread> get currentThreads => List.unmodifiable(_threads);
  ConversationThread? get activeThread => _activeThread;

  // Start a new recording session
  void startNewSession({String provider = 'Sherpa', String? audioFilePath}) {
    // If there was an active thread, close it (though we allow multiple? No, sticking to one active for now)
    if (_activeThread != null) {
      _activeThread!.isActive = false;
    }

    final newThread = ConversationThread(
      id: const Uuid().v4(),
      title: '$provider Session ${_formatDate(DateTime.now())}',
      startTime: DateTime.now(),
      transcriptionService: provider,
      messages: [],
      isActive: true,
      isUnread: true,
      audioFilePath: audioFilePath,
    );

    _activeThread = newThread;
    _threads.insert(0, newThread);
    _controller.add(_threads); // Broadcast updates
    debugPrint("Repo: Started Session ${newThread.id} (Threads: ${_threads.length})");
    
    // Add initial system message
    addMessageToActiveSession('System', 'Microphone Activated');
  }

  void endActiveSession() {
    if (_activeThread != null) {
      debugPrint("Repo: Ending Session ${_activeThread!.id} with ${_activeThread!.messages.length} messages");
      addMessageToActiveSession('System', 'Microphone Deactivated');
      _activeThread!.isActive = false;
      _activeThread = null; // No active session
      _controller.add(_threads);
    } else {
        debugPrint("Repo: EndSession called but no active thread");
    }
  }

  void addMessageToActiveSession(String sender, String text, {String? speakerId, Duration? audioStartTime, Duration? audioEndTime}) {
    if (_activeThread == null) {
      // Fallback: create a one-off thread if none exists? 
      // Or just ignore? For robustness, let's create one.
      startNewSession(provider: 'Unknown');
    }

    final newMessage = ConversationMessage(
      sender: sender,
      text: text,
      timestamp: DateTime.now(),
      speakerId: speakerId,
      audioStartTime: audioStartTime,
      audioEndTime: audioEndTime,
    );
    
    // Insert at end of list for messages (cronological)
    // Note: The threads list is reverse-cron, but messages inside are cron?
    // Note: The threads list is reverse-cron, but messages inside are cron?
    // Let's keep messages chronological [oldest ... newest]
    // But mutable list modification:
    _activeThread!.messages.add(newMessage);
    debugPrint("Repo: Added message to ${_activeThread!.id}. Total: ${_activeThread!.messages.length}");
    
    // Force update
    // Note: Should we deep copy? For Flutter reactive patterns, usually we emit new list.
    // But since we modified the object inside the list, emitting `_threads` again triggers StreamBuilder.
    _controller.add(_threads);
  }

  void updateLastMessageInActiveSession(String newText, {String? sender, String? speakerId, Duration? audioStartTime, Duration? audioEndTime}) {
      if (_activeThread == null || _activeThread!.messages.isEmpty) {
          // If no message exists to update, verify if we should add one.
          // For partial text, usually we want to start a new bubble if none exists.
          addMessageToActiveSession(sender ?? "Unknown", newText, speakerId: speakerId, audioStartTime: audioStartTime, audioEndTime: audioEndTime);
          return;
      }
      
      final lastMessage = _activeThread!.messages.last;
      
      // Update content
      lastMessage.text = newText;
      // Optional: Update sender/speaker if changed/refined
      
      // Update audio durations if provided
      if (audioEndTime != null || audioStartTime != null) {
           // We need to replace the message because duration fields are likely final in our model (checking model...)
           // Let's swap the object.
           final updatedMessage = ConversationMessage(
               id: lastMessage.id,
               sender: lastMessage.sender,
               text: newText,
               timestamp: lastMessage.timestamp,
               speakerId: speakerId ?? lastMessage.speakerId,
               audioStartTime: audioStartTime ?? lastMessage.audioStartTime,
               audioEndTime: audioEndTime ?? lastMessage.audioEndTime,
           );
           _activeThread!.messages.removeLast();
           _activeThread!.messages.add(updatedMessage);
      }
      
      // Force update
      _controller.add(_threads);
  }
  
  void updateLastMessageSpeaker(String speakerId) {
       if (_activeThread == null || _activeThread!.messages.isEmpty) return;
       
       final lastMessage = _activeThread!.messages.last;
       // Replace message with new speakerId
       final updatedMessage = ConversationMessage(
           id: lastMessage.id,
           sender: lastMessage.sender, // We might update this to Speaker Name too if we want
           text: lastMessage.text,
           timestamp: lastMessage.timestamp,
           speakerId: speakerId,
           audioStartTime: lastMessage.audioStartTime,
           audioEndTime: lastMessage.audioEndTime,
       );
       
       _activeThread!.messages.removeLast();
       _activeThread!.messages.add(updatedMessage);
       _controller.add(_threads);
  }
}

String _formatDate(DateTime dt) {
  return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
}
