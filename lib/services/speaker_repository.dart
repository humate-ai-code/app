import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_app/models/speaker_model.dart';
import 'package:uuid/uuid.dart';

class SpeakerRepository {
  static final SpeakerRepository _instance = SpeakerRepository._internal();
  factory SpeakerRepository() => _instance;
  SpeakerRepository._internal();

  List<Speaker> _speakers = [];
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    await _loadSpeakers();
    _isInitialized = true;
  }

  Future<Speaker> identify(List<double> embedding) async {
    if (!_isInitialized) await init();

    Speaker? bestMatch;
    double bestScore = -1.0;
    
    // Threshold for cosine similarity (0.0 to 1.0)
    // 0.25 - 0.4 is usually a good range for 3d-speaker/eres2net
    // We'll tune this. Let's start with 0.35
    const double threshold = 0.35; 

    for (final speaker in _speakers) {
      final score = _cosineSimilarity(speaker.embedding, embedding);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = speaker;
      }
    }

    if (bestMatch != null && bestScore >= threshold) {
      debugPrint("SpeakerRepo: Match found: ${bestMatch.name} (Score: ${bestScore.toStringAsFixed(3)})");
      // Update embedding? (Moving average logic could go here)
      return bestMatch;
    }

    // No match, create new speaker
    final newId = const Uuid().v4();
    // Default name
    final newSpeaker = Speaker(
      id: newId,
      name: "Speaker ${newId.substring(0, 4)}",
      embedding: embedding,
    );
    
    _speakers.add(newSpeaker);
    await _saveSpeakers();
    debugPrint("SpeakerRepo: Created new speaker: ${newSpeaker.name}");
    return newSpeaker;
  }
  
  Future<void> updateSpeakerName(String id, String newName) async {
      final index = _speakers.indexWhere((s) => s.id == id);
      if (index != -1) {
          _speakers[index].name = newName;
          await _saveSpeakers();
      }
  }

  Future<void> setAsUser(String id) async {
      for (var s in _speakers) {
          s.isUser = (s.id == id);
      }
      await _saveSpeakers();
  }

  Speaker? getSpeaker(String? id) {
      if (id == null) return null;
      try {
          return _speakers.firstWhere((s) => s.id == id);
      } catch (e) {
          return null;
      }
  }

  // --- Persistence ---

  Future<void> _loadSpeakers() async {
      try {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/speakers.json');
          if (await file.exists()) {
              final jsonStr = await file.readAsString();
              final List<dynamic> list = jsonDecode(jsonStr);
              _speakers = list.map((e) => Speaker.fromJson(e)).toList();
              debugPrint("SpeakerRepo: Loaded ${_speakers.length} speakers");
          }
      } catch (e) {
          debugPrint("SpeakerRepo: Error loading speakers: $e");
      }
  }

  Future<void> _saveSpeakers() async {
      try {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/speakers.json');
          final jsonStr = jsonEncode(_speakers.map((e) => e.toJson()).toList());
          await file.writeAsString(jsonStr);
      } catch (e) {
          debugPrint("SpeakerRepo: Error saving speakers: $e");
      }
  }

  // --- Math ---

  double _cosineSimilarity(List<double> v1, List<double> v2) {
      if (v1.length != v2.length) return 0.0;
      
      double dot = 0.0;
      double mag1 = 0.0;
      double mag2 = 0.0;

      for (int i = 0; i < v1.length; i++) {
          dot += v1[i] * v2[i];
          mag1 += v1[i] * v1[i];
          mag2 += v2[i] * v2[i];
      }

      mag1 = sqrt(mag1);
      mag2 = sqrt(mag2);

      if (mag1 == 0 || mag2 == 0) return 0.0;
      return dot / (mag1 * mag2);
  }
}
