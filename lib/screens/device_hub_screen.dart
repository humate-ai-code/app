import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_app/models/device_model.dart';
import 'package:flutter_app/screens/device_detail_screen.dart';
import 'package:flutter_app/screens/settings_screen.dart';
import 'package:flutter_app/services/context_action_service.dart';
import 'package:flutter_app/services/device_repository.dart';
import 'package:flutter_app/theme/app_theme.dart';
import 'package:flutter_app/widgets/context_engine_view.dart';
import 'package:flutter_app/widgets/device_grid_item.dart';

class DeviceHubScreen extends StatefulWidget {
  const DeviceHubScreen({super.key});

  @override
  State<DeviceHubScreen> createState() => _DeviceHubScreenState();
}

class _DeviceHubScreenState extends State<DeviceHubScreen> {
  // No local _devices list anymore

  List<Offset> _connectedOffsets = [];

  @override
  void initState() {
    super.initState();
    _fetchDeviceName();
    // Initialize Action Service
    ContextActionService().init();
    
    // Schedule initial position check after layout
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _updateConnectionOffsets(DeviceRepository().currentDevices);
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
       DeviceRepository().updateDeviceName('phone', deviceName);
    }
  }

  void _toggleDevice(String id) {
    DeviceRepository().toggleDeviceConnection(id);
    
    // UI updates via StreamBuilder now
    // Offsets update needs to happen after rebuild?
    // We can hook into the StreamBuilder or use a listener.
    // simpler: schedule a frame check
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _updateConnectionOffsets(DeviceRepository().currentDevices);
    });
  }

  void _updateConnectionOffsets(List<DeviceModel> devices) {
    final List<Offset> newOffsets = [];
    
    for (final device in devices) {
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
                   child: StreamBuilder<List<DeviceModel>>(
                       stream: DeviceRepository().devicesStream,
                       initialData: DeviceRepository().currentDevices,
                       builder: (context, snapshot) {
                           final devices = snapshot.data ?? [];
                           
                           // Schedule offset update on every rebuild?
                           // Risky for perf but needed for accurate lines.
                           // Or specific trigger.
                           WidgetsBinding.instance.addPostFrameCallback((_) {
                               _updateConnectionOffsets(devices);
                           });

                           return Column(
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: [
                                   const SizedBox(height: 300), 
                                   
                                   // Device Grid
                                   Row(
                                       mainAxisAlignment: MainAxisAlignment.center, 
                                       children: devices.asMap().entries.map((entry) {
                                           final device = entry.value;
                                           return Padding(
                                               padding: const EdgeInsets.symmetric(horizontal: 10),
                                               child: DeviceGridItem(
                                                   key: device.key, // Assign GlobalKey
                                                   icon: device.icon,
                                                   label: device.label,
                                                   isConnected: device.isConnected,
                                                   onTap: () => _toggleDevice(device.id),
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
                                                       // Refresh handled by stream
                                                   },
                                               ),
                                           );
                                       }).toList(),
                                   ),
                               ],
                           );
                       },
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
              onPressed: () {
                  // Allow settings even if connected, but maybe warn?
                  // The user requested reset option, which might be needed anytime.
                  // Transcription switch might arguably be blocked while recording, but let SettingsScreen handle that or just let it replace.
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
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


