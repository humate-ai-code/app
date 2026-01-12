import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_app/models/device_model.dart';
import 'package:flutter_app/screens/device_detail_screen.dart';
import 'package:flutter_app/theme/app_theme.dart';
import 'package:flutter_app/widgets/context_engine_view.dart';
import 'package:flutter_app/widgets/device_grid_item.dart';

class DeviceHubScreen extends StatefulWidget {
  const DeviceHubScreen({super.key});

  @override
  State<DeviceHubScreen> createState() => _DeviceHubScreenState();
}

class _DeviceHubScreenState extends State<DeviceHubScreen> {
  // Device List starts with just the placeholder for current phone
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

  List<Offset> _connectedOffsets = [];

  @override
  void initState() {
    super.initState();
    _fetchDeviceName();
    // Schedule initial position check after layout
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _updateConnectionOffsets();
    });
  }

  Future<void> _fetchDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceName = 'Phone';

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = iosInfo.name;
      }
    } catch (e) {
      // Fallback to generic name on error or web/other platforms
    }

    if (mounted) {
      setState(() {
        // Update the first device (Phone) label
        if (_devices.isNotEmpty) {
           // We need to replace the object or mutable field to update UI?
           // DeviceModel fields are final except isConnected.
           // Let's replace the item in the list.
           final oldPhone = _devices[0];
           _devices[0] = DeviceModel(
               id: oldPhone.id, 
               icon: oldPhone.icon, 
               label: deviceName, 
               isConnected: oldPhone.isConnected,
               sensors: oldPhone.sensors, // Preserve sensors
           );
           // We need to keep the key if we want animation continuity, but recreating it is fine for label change on load.
           // Actually DeviceModel creates a new GlobalKey() in constructor.
           // If we replace it, we lose the key and might flicker.
           // Better to make label mutable or just accept the flicker on startup. 
           // Given the prompt "Data class" in plan, I made fields final.
           // Let's just swap it.
        }
      });
      // Updating label might change width slightly, so update offsets
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _updateConnectionOffsets();
      });
    }
  }

  void _toggleDevice(int index) {
    setState(() {
      _devices[index].isConnected = !_devices[index].isConnected;
    });
    
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _updateConnectionOffsets();
    });
  }

  void _updateConnectionOffsets() {
    final List<Offset> newOffsets = [];
    
    for (final device in _devices) {
      if (device.isConnected && device.key.currentContext != null) {
        final RenderBox box = device.key.currentContext!.findRenderObject() as RenderBox;
        final Offset center = box.localToGlobal(box.size.center(Offset.zero));
        newOffsets.add(center);
      }
    }

    setState(() {
      _connectedOffsets = newOffsets;
    });
  }

  void _showAddDeviceOptions() {
      showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
              decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: SafeArea(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          Container(
                              margin: const EdgeInsets.only(top: 10, bottom: 20),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(2),
                              ),
                          ),
                          _buildAddOption(Icons.watch, "Smartwatch"),
                          _buildAddOption(Icons.headphones, "Earbuds"),
                          const SizedBox(height: 20),
                      ],
                  ),
              ),
          ),
      );
  }

  Widget _buildAddOption(IconData icon, String label) {
      return ListTile(
          leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderColor),
              ),
              child: Icon(icon, color: Colors.white),
          ),
          title: Text(
              label, 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
          ),
          onTap: () {
              Navigator.pop(context); // Close sheet
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          "$label currently not supported",
                          style: const TextStyle(color: Colors.black),
                      ),
                      backgroundColor: AppColors.neonGreen,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
              );
          },
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
             child: ContextEngineView(connectedDeviceOffsets: _connectedOffsets),
          ),
          
          // Foreground Layout
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               _buildHeader(),
               Expanded(
                   child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                           const SizedBox(height: 300), 
                           
                           // Device Grid
                           Row(
                               mainAxisAlignment: MainAxisAlignment.center, // Center chips since we might only have one
                               children: _devices.asMap().entries.map((entry) {
                                   final index = entry.key;
                                   final device = entry.value;
                                   // Add spacing if not first
                                   return Padding(
                                       padding: const EdgeInsets.symmetric(horizontal: 10),
                                       child: DeviceGridItem(
                                           key: device.key, // Assign GlobalKey
                                           icon: device.icon,
                                           label: device.label,
                                           isConnected: device.isConnected,
                                           onTap: () => _toggleDevice(index),
                                           onLongPress: () async {
                                               await Navigator.of(context).push(
                                                   PageRouteBuilder(
                                                       pageBuilder: (context, animation, secondaryAnimation) => DeviceDetailScreen(device: device),
                                                       transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                           const begin = Offset(0.0, 1.0);
                                                           const end = Offset.zero;
                                                           const curve = Curves.ease;
                                                           var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                                           return SlideTransition(position: animation.drive(tween), child: child);
                                                       },
                                                   ),
                                               );
                                               // Refresh state when returning from detail screen
                                               if (mounted) {
                                                   setState(() {});
                                                   SchedulerBinding.instance.addPostFrameCallback((_) {
                                                       _updateConnectionOffsets();
                                                   });
                                               }
                                           },
                                       ),
                                   );
                               }).toList(),
                           ),
                       ],
                   ),
               ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              onPressed: () {},
            ),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppColors.cyanAccent, AppColors.purpleAccent],
              ).createShader(bounds),
              child: const Text(
                'C&C',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: _showAddDeviceOptions,
            ),
          ],
        ),
      ),
    );
  }
}


