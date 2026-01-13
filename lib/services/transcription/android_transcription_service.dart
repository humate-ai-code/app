import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_app/repositories/conversation_repository.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import 'transcription_service.dart';

class AndroidTranscriptionService implements TranscriptionService {


  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  @override
  Future<void> init() async {
    if (_isInitialized) return;
    try {
        _isInitialized = await _speechToText.initialize(
            onError: (val) {
                 debugPrint('AndroidSTT: Error: $val');
                 // Restart on error if supposed to be listening
                 if (_isListening) {
                     Future.delayed(const Duration(seconds: 1), _listen);
                 }
            },
            onStatus: (val) {
                debugPrint('AndroidSTT: Status: $val');
                if ((val == 'done' || val == 'notListening') && _isListening) {
                    // Automatically restart
                    debugPrint("AndroidSTT: Restarting listener...");
                    _listen();
                }
            },
        );
        debugPrint("AndroidSTT: Initialized: $_isInitialized");
    } catch (e) {
        debugPrint("AndroidSTT: Init Failed: $e");
    }
  }

  @override
  Future<void> start() async {
    if (!_isInitialized) await init();
    if (_speechToText.isListening) return;

    if (await Permission.microphone.request().isGranted) {
        if (!_isListening) {
             ConversationRepository().startNewSession(provider: 'Android'); 
             _isListening = true;
        }
        
        await _listen();
    }
  }

  Future<void> _listen() async {
      if (!_isListening) return;
      
      try {
        await _speechToText.listen(
            onResult: _onSpeechResult,
            listenFor: const Duration(minutes: 5), // Try longer duration
            pauseFor: const Duration(seconds: 10), // Allow longer pauses
            listenOptions: SpeechListenOptions(
                partialResults: true,
                cancelOnError: false, // Don't cancel on minor errors
                listenMode: ListenMode.dictation,
            ),
        );
        debugPrint("AndroidSTT: Listening...");
      } catch (e) {
          debugPrint("AndroidSTT: Listen Error: $e");
          // Retry if error
          if (_isListening) {
              Future.delayed(const Duration(seconds: 1), _listen);
          }
      }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
      if (result.finalResult) {
          debugPrint("AndroidSTT: Final: ${result.recognizedWords}");
          ConversationRepository().addMessageToActiveSession('User', result.recognizedWords);

          
          // Android STT stops after final result usually, so we might need to restart?
          // For continuous:
          if (!_speechToText.isListening) {
             // restart? 
             // Depending on behavior, `listen` might need to be called again.
             // But for now let's behave like standard dictation.
          }
      } else {
        // Partial results ignored for now, or add Repo update here
      }
  }

  @override
  Future<void> stop() async {
      _isListening = false;
      await _speechToText.stop();
      ConversationRepository().endActiveSession();
      debugPrint("AndroidSTT: Stopped listening");
  }
}
