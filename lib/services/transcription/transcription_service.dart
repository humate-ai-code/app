import 'dart:async';

abstract class TranscriptionService {


  Future<void> init();
  Future<void> start();
  Future<void> stop();
}
