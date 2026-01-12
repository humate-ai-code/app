import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_app/models/device_model.dart';

class DeviceRepository {
  static final DeviceRepository _instance = DeviceRepository._internal();
  factory DeviceRepository() => _instance;
  DeviceRepository._internal();

  // Initial State
  final List<DeviceModel> _devices = [
    DeviceModel(
        id: 'phone', 
        icon: Icons.smartphone, 
        label: 'Phone', 
        isConnected: true,
        sensors: [
            SensorModel(id: 'mic', icon: Icons.mic, label: 'Microphone', isConnected: true),
        ],
    ),
  ];

  final _controller = StreamController<List<DeviceModel>>.broadcast();

  Stream<List<DeviceModel>> get devicesStream => _controller.stream;
  List<DeviceModel> get currentDevices => List.unmodifiable(_devices);

  void updateDeviceName(String id, String name) {
      final index = _devices.indexWhere((d) => d.id == id);
      if (index != -1) {
          final old = _devices[index];
          _devices[index] = DeviceModel(
              id: old.id,
              icon: old.icon,
              label: name,
              isConnected: old.isConnected,
              sensors: old.sensors,
          );
          _controller.add(_devices);
      }
  }

  void toggleDeviceConnection(String id) {
      final index = _devices.indexWhere((d) => d.id == id);
      if (index != -1) {
          final old = _devices[index];
          old.isConnected = !old.isConnected;
          // Note: DeviceModel is technically mutable in isConnected per previous view, 
          // but let's treat it as mostly immutable or just notify.
          // In the current model, `isConnected` is mutable.
          // But to be safe and trigger updates:
          _controller.add(_devices);
      }
  }
}
