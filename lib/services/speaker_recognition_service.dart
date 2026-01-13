
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

class SpeakerRecognitionService {
    static final SpeakerRecognitionService _instance = SpeakerRecognitionService._internal();
    factory SpeakerRecognitionService() => _instance;
    SpeakerRecognitionService._internal();

    sherpa.SpeakerEmbeddingExtractor? _extractor;
    bool _isInitialized = false;

    Future<void> init() async {
        if (_isInitialized) return;
        
        try {
            debugPrint("SpeakerService: Initializing...");
            
            // Initialize global bindings
            sherpa.initBindings();
            
            // Assets (using 3d-speaker-16k models)
            const modelBase = 'assets/models';
            // Note: The specific model filename depends on what's in assets.
            // Checked earlier: "3dspeaker_speech_eres2net_base_sv_zh-cn_3dspeaker_16k.onnx"
            // Wait, the earlier list_dir showed that specific file.
            
            final modelPath = await _copyAsset('$modelBase/3dspeaker_speech_eres2net_base_sv_zh-cn_3dspeaker_16k.onnx');

            final config = sherpa.SpeakerEmbeddingExtractorConfig(
                model: modelPath,
                numThreads: 1,
                debug: false,
                provider: "cpu",
            );
            
            _extractor = sherpa.SpeakerEmbeddingExtractor(config: config);
            _isInitialized = true;
            debugPrint("SpeakerService: Initialized.");
        } catch (e) {
            debugPrint("SpeakerService: Init Error: $e");
        }
    }

    Future<List<double>?> extractEmbedding(String audioPath, Duration start, Duration end) async {
        if (!_isInitialized) await init();
        if (_extractor == null) return null;

        try {
            // 1. Read the audio file
            final file = File(audioPath);
            if (!await file.exists()) return null;
            
            final bytes = await file.readAsBytes();
            if (bytes.length < 44) return null;
            
            // 2. Parse WAV (basic) to find PCM offset
            // Typically header is 44 bytes.
            final pcmData = bytes.sublist(44); 
            
            // 3. Slice the data based on sample rate (16000) * 2 bytes/sample (16-bit)
            
            final startByte = start.inMilliseconds * 32; // (ms * 16 * 2) -> ms * 32
            final endByte = end.inMilliseconds * 32;
            
            if (startByte >= pcmData.length) return null;
            
            final safeEndByte = endByte > pcmData.length ? pcmData.length : endByte;
            if (safeEndByte <= startByte) return null;
            
            final segmentBytes = pcmData.sublist(startByte, safeEndByte);
            
            // 4. Convert Int16 bytes to Float32 list [-1.0, 1.0]
            final floatSamples = _convertInt16ToFloat32(segmentBytes);

            // 5. Compute embedding
            final stream = _extractor!.createStream();
            stream.acceptWaveform(samples: floatSamples, sampleRate: 16000);
            
            // Check if enough data?
            if (_extractor!.isReady(stream)) {
                 final embedding = _extractor!.compute(stream);
                 stream.free();
                 // embedding is Float32List, convert to List<double>
                 return embedding.toList();
            } else {
                 stream.free();
                 return null;
            }

        } catch (e) {
            debugPrint("SpeakerService: Extraction Error: $e");
            return null;
        }
    }
    
    Float32List _convertInt16ToFloat32(Uint8List data) {
       final buffer = data.buffer;
       final int16List = Int16List.view(buffer);
       final float32List = Float32List(int16List.length);
       for (var i = 0; i < int16List.length; i++) {
           float32List[i] = int16List[i] / 32768.0;
       }
       return float32List;
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
}
