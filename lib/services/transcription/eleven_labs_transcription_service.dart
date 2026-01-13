import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_app/services/conversation_repository.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:flutter_app/services/speaker_recognition_service.dart';
import 'package:flutter_app/services/speaker_repository.dart';

import 'transcription_service.dart';

class ElevenLabsTranscriptionService implements TranscriptionService {


  WebSocketChannel? _channel;
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isListening = false;
  String? _currentAudioFilePath; // Store path for speaker ID access
  
  // Map "speaker_0" to "Alice" etc.
  final Map<String, String> _speakerNames = {};

  @override
  Future<void> init() async {
    await dotenv.load();
    // No specific init needed for WS until start
  }

  @override
  @override
  Future<void> start() async {
    if (_isListening) {
        debugPrint("ElevenLabs: Already listening, ignoring start request");
        return;
    }
    // Set listening immediately to prevent race conditions
    _isListening = true;

    final apiKey = dotenv.env['ELEVENLABS_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
        debugPrint("ElevenLabs: Missing API Key");
        _isListening = false;
        return;
    }

    if (await Permission.microphone.request().isGranted) {
        
        // 1. Prepare Audio File
        final dir = await getApplicationDocumentsDirectory();
        final filePath = '${dir.path}/session_${DateTime.now().millisecondsSinceEpoch}.wav';
        _currentAudioFilePath = filePath;
        
        final file = File(filePath);
        final raf = await file.open(mode: FileMode.write);
        
        // Write placeholder WAV header (44 bytes)
        // We will overwrite this on stop() with specific sizes
        await raf.writeFrom(List.filled(44, 0));
        
        ConversationRepository().startNewSession(provider: 'ElevenLabs', audioFilePath: filePath);
        
        // Init Speaker Services (lazy)
        SpeakerRepository().init();
        SpeakerRecognitionService().init();
        
        // 2. Connect WS
        final url = Uri(
            scheme: 'wss',
            host: 'api.elevenlabs.io',
            path: '/v1/speech-to-text/realtime',
            queryParameters: {
                'model_id': 'scribe_v2_realtime',
                'vad_threshold': '0.8',
                'vad_silence_threshold_secs': '0.5',
                'commit_strategy': 'vad',
                'include_language_detection': 'true',
                'include_timestamps': 'true',
                'timestamps_granularity': 'word',
            },
        );
        
        try {
            debugPrint("ElevenLabs: Connecting to $url");
            _channel = IOWebSocketChannel.connect(
                url,
                headers: {
                    'xi-api-key': apiKey.trim(),
                },
            );

            debugPrint("ElevenLabs: WS Connected");

            // 3. Listen to WS
            _channel!.stream.listen((message) {
                _handleWsMessage(message);
            }, onError: (e) {
                 debugPrint("ElevenLabs WS Error: $e");
                 stop();
            }, onDone: () {
                 debugPrint("ElevenLabs WS Closed");
                 stop();
            });

            // 4. Start Mic
            final stream = await _audioRecorder.startStream(const RecordConfig(
                encoder: AudioEncoder.pcm16bits,
                sampleRate: 16000,
                numChannels: 1,
            ));
            
            _streamCompleter = Completer<void>();

            int chunkCount = 0;
            
             // We need to keep raf open for duration of session
             _audioFileRaf = raf;

            stream.listen((data) {
                if (!_isListening) return;
                
                // Write audio to local file
                _audioFileRaf?.writeFromSync(data);

                chunkCount++;
                if (chunkCount % 50 == 0) {
                    debugPrint("ElevenLabs: Sent 50 chunks (last size: ${data.length} bytes)");
                }

                final audioMsg = {
                    "message_type": "input_audio_chunk",
                    "audio_base_64": base64Encode(data),
                    "sample_rate": 16000,
                };
                _channel?.sink.add(jsonEncode(audioMsg));
            }, onDone: () {
                debugPrint("ElevenLabs: Mic Stream Done");
                if (_streamCompleter?.isCompleted == false) {
                    _streamCompleter?.complete();
                }
            });
            debugPrint("ElevenLabs: Started Streaming to $filePath");

        } catch (e) {
            debugPrint("ElevenLabs Error: $e");
            stop();
        }
    } else {
        _isListening = false;
    }
  }

  RandomAccessFile? _audioFileRaf;
  Completer<void>? _streamCompleter;



  // Tracking state for partial bubbles
  bool _hasActivePartial = false;

  void _handleWsMessage(dynamic message) {
      if (message is String) {
          debugPrint("ElevenLabs RAW: $message"); // Reduce noise if working
          try {
              final data = jsonDecode(message);
              final type = data['message_type'];

              if (type == 'partial_transcript') {
                  final text = data['text'] as String? ?? "";
                  if (text.isNotEmpty) {

                      
                      // Update UI bubble
                      String speakerId = "user"; // Guess default
                      String senderName = _speakerNames[speakerId] ?? "Speaker";
                      
                      if (_hasActivePartial) {
                          ConversationRepository().updateLastMessageInActiveSession(text, sender: senderName);
                      } else {
                          // Start new bubble for this utterance
                          ConversationRepository().addMessageToActiveSession(senderName, text, speakerId: speakerId);
                          _hasActivePartial = true;
                      }
                  }
              } else if (type == 'committed_transcript_with_timestamps' || type == 'committed_transcript') {
                  final text = data['text'] as String? ?? "";
                  final speakerId = "user"; 
                  String senderName = _speakerNames[speakerId] ?? "Speaker";

                  // Finalize logic
                  if (text.isNotEmpty) {
                      Duration? audioStart;
                      Duration? audioEnd;
                      
                      // Parse timestamps if enabled/available
                      // Example: words: [{"text": "Hello", "start": 0.5, "end": 0.9}, ...]
                      final words = data['words'] as List<dynamic>?;
                      if (words != null && words.isNotEmpty) {
                          final firstWord = words.first;
                          final lastWord = words.last;
                          if (firstWord['start'] != null) {
                              audioStart = Duration(milliseconds: ((firstWord['start'] as num) * 1000).toInt());
                          }
                          if (lastWord['end'] != null) {
                              audioEnd = Duration(milliseconds: ((lastWord['end'] as num) * 1000).toInt());
                          }
                      }

                      bool isTimestampUpdate = false;
                      if (_hasActivePartial) {
                          ConversationRepository().updateLastMessageInActiveSession(text, sender: senderName, audioEndTime: audioEnd);
                          _hasActivePartial = false; 
                      } else {
                          // Check for duplicate
                          final lastMessage = ConversationRepository().activeThread?.messages.lastOrNull;
                          if (lastMessage != null && lastMessage.text == text) {
                              // It's a duplicate text, but if we have new timestamps, update them!
                              if (audioStart != null || audioEnd != null) {
                                  debugPrint("ElevenLabs: Updating timestamps for duplicate '$text'");
                                  ConversationRepository().updateLastMessageInActiveSession(
                                      text, 
                                      sender: senderName,
                                      audioStartTime: audioStart,
                                      audioEndTime: audioEnd
                                  );
                                  isTimestampUpdate = true;
                              } else {
                                  debugPrint("ElevenLabs: Ignoring duplicate commit for '$text' (no timestamps)");
                                  return;
                              }
                          } else {
                              ConversationRepository().addMessageToActiveSession(senderName, text, speakerId: speakerId, audioStartTime: audioStart, audioEndTime: audioEnd);
                          }
                      }
                      

                      debugPrint("ElevenLabs Final: $text (Time: $audioStart - $audioEnd)");
                      
                      // Trigger Speaker ID if we have valid audio range and file
                      if ((audioStart != null && audioEnd != null) && _currentAudioFilePath != null) {
                          _identifySpeaker(text, audioStart, audioEnd, isDuplicate: isTimestampUpdate);
                      }
                  }
              } else if (type == 'session_started') {
                  debugPrint("ElevenLabs: Session Started ${data['session_id']}");
              }
              
          } catch (e) {
              debugPrint("ElevenLabs Parse Error: $e");
          }
      }
  }
  


  @override
  Future<void> stop() async {
    _isListening = false;
    await _audioRecorder.stop();
    _channel?.sink.close();
    ConversationRepository().endActiveSession();
    debugPrint("ElevenLabs: Stopped");
    
    // Allow any pending write operations to complete
    // Wait for stream to actually finish (onDone called)
    if (_streamCompleter != null) {
        try {
            debugPrint("ElevenLabs: Waiting for stream to convert/finish...");
            await _streamCompleter!.future.timeout(const Duration(seconds: 2));
        } catch (e) {
             debugPrint("ElevenLabs: Stream wait timeout/error: $e");
        }
    } else {
        await Future.delayed(const Duration(milliseconds: 500));
    }

    // Finalize WAV Header
    if (_audioFileRaf != null) {
        try {
           final raf = _audioFileRaf!;
           // Check if it's open? 
           // raf.length() is async.
           
           final dataLength = await raf.length() - 44;
           await raf.setPosition(0);
           
           // Write Header
           // RIFF
           await raf.writeFrom(utf8.encode('RIFF'));
           // File size - 8
           await _writeInt32(raf, dataLength + 36);
           // WAVE
           await raf.writeFrom(utf8.encode('WAVE'));
           // fmt 
           await raf.writeFrom(utf8.encode('fmt '));
           // Subchunk1Size (16 for PCM)
           await _writeInt32(raf, 16);
           // AudioFormat (1 for PCM)
           await _writeInt16(raf, 1);
           // NumChannels (1)
           await _writeInt16(raf, 1);
           // SampleRate (16000)
           await _writeInt32(raf, 16000);
           // ByteRate (SampleRate * NumChannels * BitsPerSample/8) -> 16000 * 1 * 2 = 32000
           await _writeInt32(raf, 32000);
           // BlockAlign (NumChannels * BitsPerSample/8) -> 2
           await _writeInt16(raf, 2);
           // BitsPerSample (16)
           await _writeInt16(raf, 16);
           
           // data
           await raf.writeFrom(utf8.encode('data'));
           // Subchunk2Size (dataLength)
           await _writeInt32(raf, dataLength);
           
           await raf.close();
           _audioFileRaf = null;
           debugPrint("ElevenLabs: Audio file finalized.");
        } catch (e) {
            debugPrint("ElevenLabs: Error finalizing audio file: $e");
        }
    }
  }

  Future<void> _writeInt32(RandomAccessFile raf, int value) async {
      await raf.writeByte(value & 0xFF);
      await raf.writeByte((value >> 8) & 0xFF);
      await raf.writeByte((value >> 16) & 0xFF);
      await raf.writeByte((value >> 24) & 0xFF);
  }

  Future<void> _writeInt16(RandomAccessFile raf, int value) async {
      await raf.writeByte(value & 0xFF);
      await raf.writeByte((value >> 8) & 0xFF);
  }
  
  Future<void> _identifySpeaker(String text, Duration start, Duration end, {bool isDuplicate = false}) async {
      if (_currentAudioFilePath == null) return;
      
      // Extract embedding
      // We assume the audio file has the data for [start, end].
      final embedding = await SpeakerRecognitionService().extractEmbedding(
          _currentAudioFilePath!, 
          start, 
          end
      );
      
      if (embedding != null) {
          final speaker = await SpeakerRepository().identify(embedding);
          debugPrint("ElevenLabs: Identified speaker ${speaker.name} (${speaker.id}) for '$text'");
          
          // Update the message
          ConversationRepository().updateLastMessageSpeaker(speaker.id);
          
          // Optional: Update the "sender" field if it was generic "Speaker"
          // We can do that inside ConversationRepository or separate call.
      } else {
          debugPrint("ElevenLabs: Could not extract embedding for speaker ID.");
      }
  }
}
