import 'dart:async';

abstract class TranscriptionService {
  Stream<String> get onFinalizedText; // Stream of completed sentences
  Stream<String> get onPartialText;   // Stream of live updates (optional)

  Future<void> init();
  Future<void> start();
  Future<void> stop();
}
