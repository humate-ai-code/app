import 'dart:async';


import 'package:flutter/material.dart';
import 'package:flutter_app/models/device_model.dart';
import 'package:flutter_app/services/transcription/sherpa_transcription_service.dart';
import 'package:flutter_app/services/transcription/transcription_service.dart';

import 'package:flutter_app/services/transcription/android_transcription_service.dart';
import 'package:flutter_app/services/transcription/eleven_labs_transcription_service.dart';
import 'package:flutter_app/services/device_repository.dart';

class ContextActionService {
  static final ContextActionService _instance = ContextActionService._internal();
  factory ContextActionService() => _instance;
  ContextActionService._internal();

  bool _isInitialized = false;
  // bool _isListening = false; // Unused
  bool _wasMicActive = false;
  String currentProvider = 'ElevenLabs'; // Default

  late TranscriptionService _transcriptionService;

  Future<void> init() async {
    if (_isInitialized) return;

    await _initService(currentProvider);
    
    // Listen to Device Repository changes
    DeviceRepository().devicesStream.listen((devices) {
        _handleDeviceStateChange(devices);
    });
    
    // Initial check
    _handleDeviceStateChange(DeviceRepository().currentDevices);

    _isInitialized = true;
    debugPrint("ActionService: Initialized.");
  }

  Future<void> switchProvider(String provider) async {
      debugPrint("ActionService: Switching to $provider");
      if (_isInitialized) {
          // Stop current if running?
          await _transcriptionService.stop(); 
      }
      
      currentProvider = provider;
      await _initService(provider);
      
      // Re-trigger state check to restart with new provider if needed
      _handleDeviceStateChange(DeviceRepository().currentDevices);
  }

  Future<void> _initService(String provider) async {
    switch (provider) {
        case 'Android':
            _transcriptionService = AndroidTranscriptionService();
            break;
        case 'ElevenLabs':
            _transcriptionService = ElevenLabsTranscriptionService();
            break;
        case 'Sherpa':
        default:
            _transcriptionService = SherpaTranscriptionService();
            break;
    }
    
    await _transcriptionService.init();

    // Listeners can be used for UI feedback or debugging, 
    // but the Service itself now updates the Repository.
  }

  // Renamed from updateState to internal handler
  Future<void> _handleDeviceStateChange(List<DeviceModel> devices) async {
    final phone = devices.firstWhere((d) => d.id == 'phone', orElse: () => DeviceModel(id: 'null', icon: Icons.error, label: '', isConnected: false));
    if (phone.id == 'null') return;
    
    final mic = phone.sensors.firstWhere((s) => s.id == 'mic', orElse: () => SensorModel(id: 'null', icon: Icons.error, label: '', isConnected: false));

    final shouldMicBeActive = phone.isConnected && mic.isConnected;

    if (shouldMicBeActive && !_wasMicActive) {
      debugPrint('System: Triggering Mic Activation...');
      await _startListening();
    } else if (!shouldMicBeActive && _wasMicActive) {
      debugPrint('System: Triggering Mic Deactivation...');
      await _stopListening();
    }
    _wasMicActive = shouldMicBeActive;
  }

  Future<void> _startListening() async {
    if (!_isInitialized) await init();
    
    await _transcriptionService.start();
  }

  Future<void> _stopListening() async {
    await _transcriptionService.stop();
  }
}
