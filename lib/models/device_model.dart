import 'package:flutter/material.dart';

class SensorModel {
  final String id;
  final IconData icon;
  final String label;
  bool isConnected;
  final bool isSupported;
  final GlobalKey key;

  SensorModel({
    required this.id,
    required this.icon,
    required this.label,
    this.isConnected = false,
    this.isSupported = true,
  }) : key = GlobalKey();
}

class DeviceModel {
  final String id;
  final IconData icon;
  final String label;
  bool isConnected;
  final GlobalKey key;
  final List<SensorModel> sensors;

  DeviceModel({
    required this.id,
    required this.icon,
    required this.label,
    this.isConnected = false,
    List<SensorModel>? sensors,
  }) : key = GlobalKey(),
       sensors = sensors ?? [];
}
