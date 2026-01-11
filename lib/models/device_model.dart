import 'package:flutter/material.dart';

class DeviceModel {
  final String id;
  final IconData icon;
  final String label;
  bool isConnected;
  final GlobalKey key;

  DeviceModel({
    required this.id,
    required this.icon,
    required this.label,
    this.isConnected = false,
  }) : key = GlobalKey();
}
