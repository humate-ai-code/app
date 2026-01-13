import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app/models/conversation_model.dart';
import 'package:flutter_app/models/task_model.dart';
import 'package:flutter_app/repositories/conversation_repository.dart';
import 'package:flutter_app/repositories/task_repository.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiAnalysisService {
  static final GeminiAnalysisService _instance = GeminiAnalysisService._internal();
  factory GeminiAnalysisService() => _instance;
  GeminiAnalysisService._internal();

  GenerativeModel? _model;
  bool _isInitialized = false;
  
  // Debounce tracking
  Timer? _debounceTimer;
  final Duration _debounceDuration = const Duration(seconds: 20); // Wait 20s of silence? Or maybe longer.

  Future<void> init() async {
    if (_isInitialized) return;

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null) {
      debugPrint("GeminiService: No API Key found in .env");
      return;
    }

    _model = GenerativeModel(
      model: 'gemini-3-flash-preview', // Fast model for frequent updates
      apiKey: apiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );
    
    _isInitialized = true;
    
    // Listen to conversation updates to trigger analysis
    ConversationRepository().threadsStream.listen((threads) {
        _checkAndTriggerAnalysis(threads);
    });
    
    debugPrint("GeminiService: Initialized.");
  }
  
  void _checkAndTriggerAnalysis(List<ConversationThread> threads) {
      final activeThread = ConversationRepository().activeThread;
      if (activeThread == null) return;
      
      // If we have messages
      if (activeThread.messages.isEmpty) return;
      
      // Check if we have new messages since last analysis
      final lastMsgId = activeThread.messages.last.id;
      if (lastMsgId != activeThread.lastAnalyzedMessageId) {
           // We have new content. Reset debounce timer.
           _debounceTimer?.cancel();
           _debounceTimer = Timer(_debounceDuration, () {
               analyzeConversation(activeThread);
           });
      }
  }

  Future<void> analyzeConversation(ConversationThread thread) async {
    if (!_isInitialized || _model == null) {
        await init();
        if (_model == null) return;
    }
    
    debugPrint("GeminiService: analyzing thread ${thread.id}...");
    
    // 1. Prepare Content
    // We analyze the whole conversation context for better quality, 
    // or we could optimize to only send new part if we had a persistent chat session (not yet).
    // For now, let's send full status.
    
    final currentTasks = TaskRepository().currentTasks;
    final messagesText = thread.messages.map((m) => "[${m.id}] ${m.sender}: ${m.text}").join("\n");
    final tasksJson = jsonEncode(currentTasks.map((t) => t.toJson()).toList());

    final prompt = '''
    You are an intelligent personal assistant analyzing a conversation (likely a voice recording transcription).
    
    Your goal is to:
    1. Extract generic TASKS explicitly mentioned or implied by the user.
    2. Identify UPDATES to existing tasks (completed, rescheduled, details added).
    3. Generate a concise SUMMARY of the conversation so far.
    4. Generate a short, descriptive TITLE for the conversation (max 5-6 words).
    
    Current Tasks:
    $tasksJson
    
    Conversation History:
    $messagesText
    
    Return a JSON object:
    {
      "newTasks": [
         { "title": "...", "description": "...", "dueDate": "ISO8601", "status": "pending", "sourceMessageId": "ID of message triggering this" }
      ],
      "taskUpdates": [
         { "id": "EXISTING_TASK_ID", "status": "done", ...any other field to update... }
      ],
      "summary": "...",
      "title": "..."
    }
    
    Rules:
    - Do not duplicate tasks if they already exist in Current Tasks.
    - Be concise.
    - If user says "I did X", mark X as done.
    ''';

    try {
        final content = [Content.text(prompt)];
        final response = await _model!.generateContent(content);
        
        if (response.text != null) {
           _processResponse(response.text!, thread);
        }
    } catch (e) {
        debugPrint("GeminiService: Error analyzing - $e");
    }
  }
  
  void _processResponse(String jsonStr, ConversationThread thread) {
      try {
          final data = jsonDecode(jsonStr);
          
          // 1. Handle Tasks
          final List<Task> newTasks = [];
          if (data['newTasks'] != null) {
              for (var t in data['newTasks']) {
                  newTasks.add(Task(
                      id: const Uuid().v4(),
                      title: t['title'],
                      description: t['description'] ?? '',
                      dueDate: t['dueDate'] != null ? DateTime.tryParse(t['dueDate']) : null,
                      status: t['status'] ?? 'pending',
                      sourceConversationId: thread.id,
                      sourceMessageId: t['sourceMessageId']
                  ));
              }
          }
          
          List<Map<String, dynamic>> updates = [];
          if (data['taskUpdates'] != null) {
              updates = List<Map<String, dynamic>>.from(data['taskUpdates']);
          }
          
          TaskRepository().handleAnalysisUpdates(newTasks: newTasks, updates: updates);
          
          // 2. Update Conversation
          final String? summary = data['summary'];
          final String? title = data['title'];
          final String lastMsgId = thread.messages.isNotEmpty ? thread.messages.last.id : "";
          
          if (summary != null || title != null) {
              ConversationRepository().updateThreadProperties(
                  thread.id, 
                  summary: summary, 
                  title: title,
                  lastAnalyzedMessageId: lastMsgId
              );
          }
          
          debugPrint("GeminiService: Analysis complete. Found ${newTasks.length} tasks, ${updates.length} updates.");
          
      } catch (e) {
          debugPrint("GeminiService: parsing error $e");
      }
  }
}
