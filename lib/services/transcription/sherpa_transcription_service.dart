import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:flutter_app/services/conversation_repository.dart';

import 'transcription_service.dart';

class SherpaTranscriptionService implements TranscriptionService {
  final _onFinalizedTextController = StreamController<String>.broadcast();
  final _onPartialTextController = StreamController<String>.broadcast();

  @override
  Stream<String> get onFinalizedText => _onFinalizedTextController.stream;

  @override
  Stream<String> get onPartialText => _onPartialTextController.stream;

  bool _isInitialized = false;
  bool _isListening = false;

  final _audioRecorder = AudioRecorder();
  sherpa.OnlineRecognizer? _recognizer;
  sherpa.OnlineStream? _stream;

  @override
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      debugPrint("SherpaService: Initializing...");
      
      // Initialize the native engine
      sherpa.initBindings();
      
      // 1. Copy Assets
      // ASR Models
      final encoderPath = await _copyAsset('assets/models/sherpa-onnx-streaming-zipformer-en-2023-02-21/encoder-epoch-99-avg-1.int8.onnx');
      final decoderPath = await _copyAsset('assets/models/sherpa-onnx-streaming-zipformer-en-2023-02-21/decoder-epoch-99-avg-1.int8.onnx');
      final joinerPath = await _copyAsset('assets/models/sherpa-onnx-streaming-zipformer-en-2023-02-21/joiner-epoch-99-avg-1.int8.onnx');
      final tokensPath = await _copyAsset('assets/models/sherpa-onnx-streaming-zipformer-en-2023-02-21/tokens.txt');

      // 2. Init ASR
      final config = sherpa.OnlineRecognizerConfig(
        model: sherpa.OnlineModelConfig(
          transducer: sherpa.OnlineTransducerModelConfig(
            encoder: encoderPath,
            decoder: decoderPath,
            joiner: joinerPath,
          ),
          tokens: tokensPath,
          numThreads: 1,
        ),
      );
      _recognizer = sherpa.OnlineRecognizer(config);

      _isInitialized = true;
      debugPrint("SherpaService: Initialized.");
    } catch (e) {
      debugPrint("SherpaService: Error initializing: $e");
    }
  }

  @override
  Future<void> start() async {
    if (!_isInitialized) await init();
    if (_isListening) return;

    if (await Permission.microphone.request().isGranted) {
      // Create a fresh stream for the recognizer
      _stream = _recognizer?.createStream();
      _isListening = true;
      ConversationRepository().startNewSession(provider: 'Sherpa');

      try {
        final audioStream = await _audioRecorder.startStream(
            const RecordConfig(
                encoder: AudioEncoder.pcm16bits, 
                sampleRate: 16000,
                numChannels: 1,
            ),
        );

        audioStream.listen((data) {
            if (!_isListening) return;

            final floatSamples = _convertInt16ToFloat32(data);
            
            _stream?.acceptWaveform(samples: floatSamples, sampleRate: 16000);
            
            while (_recognizer?.isReady(_stream!) ?? false) {
               _recognizer?.decode(_stream!);
            }

            final result = _recognizer?.getResult(_stream!);
            final isEndpoint = _recognizer?.isEndpoint(_stream!) ?? false;

            if (result != null && result.text.isNotEmpty) {
               if (isEndpoint) {
                 debugPrint("SherpaService: Endpoint. Final: ${result.text}");
                 ConversationRepository().addMessageToActiveSession('Unknown', result.text);
                 _onFinalizedTextController.add(result.text);
                 _recognizer?.reset(_stream!);
               } else {
                 // Partial
                 // ConversationRepository().updateLiveMessage ... (Future feature)
                 _onPartialTextController.add(result.text);
               }
            }
        });
        debugPrint("SherpaService: Started listening.");
      } catch (e) {
          debugPrint("SherpaService: Recorder Error: $e");
          _isListening = false;
      }
    }
  }

  @override
  Future<void> stop() async {
    if (!_isListening) return;
    _isListening = false;
    await _audioRecorder.stop();
    _stream?.free();
    ConversationRepository().endActiveSession();
    debugPrint("SherpaService: Stopped listening.");
  }

  Future<String> _copyAsset(String assetPath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final filename = assetPath.split('/').last;
    final file = File('${docsDir.path}/$filename');
    
    if (!await file.exists()) {
       final data = await rootBundle.load(assetPath);
       final bytes = data.buffer.asUint8List();
       await file.writeAsBytes(bytes);
    }
    return file.path;
  }
  
  Float32List _convertInt16ToFloat32(Uint8List data) {
      final int16List = Int16List.view(data.buffer);
      final float32List = Float32List(int16List.length);
      for (var i = 0; i < int16List.length; i++) {
          float32List[i] = int16List[i] / 32768.0;
      }
      return float32List;
  }
}
