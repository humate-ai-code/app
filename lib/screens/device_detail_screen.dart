import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_app/models/device_model.dart';
import 'package:flutter_app/theme/app_theme.dart';
import 'package:flutter_app/widgets/context_engine_view.dart';


class DeviceDetailScreen extends StatefulWidget {
  final DeviceModel device;

  const DeviceDetailScreen({super.key, required this.device});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  // We need to manage local state for animations, but the device object is passed in.
  // Changes here should probably reflect back to the main list (by reference).
  
  List<Offset> _sensorOffsets = [];
  
  // Custom keys for local sensors to track positions
  // We can't use the keys in the models because they might be in use elsewhere? 
  // Actually, GlobalKeys must be unique in the tree. 
  // If the device is in the Hub, we can't show the SAME widget with the SAME key here.
  // The User wants to edit the device. 
  // The Sensors are NEW widgets here.
  
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _updateConnectionOffsets();
    });
  }

  void _toggleSensor(int index) {
    setState(() {
      widget.device.sensors[index].isConnected = !widget.device.sensors[index].isConnected;
    });
    SchedulerBinding.instance.addPostFrameCallback((_) {
       _updateConnectionOffsets();
    });
  }
  
  void _updateConnectionOffsets() {
    final List<Offset> newOffsets = [];
    for (final sensor in widget.device.sensors) {
      if (sensor.isConnected && sensor.key.currentContext != null) {
        final RenderBox box = sensor.key.currentContext!.findRenderObject() as RenderBox;
        final Offset center = box.localToGlobal(box.size.center(Offset.zero));
        newOffsets.add(center);
      }
    }
    setState(() {
      _sensorOffsets = newOffsets;
    });
  }
  
  void _showAddSensorOptions() {
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
                          _buildAddOption(Icons.camera_alt, "Camera"),
                          _buildAddOption(Icons.gps_fixed, "GPS"),
                          _buildAddOption(Icons.explore, "Gyroscope"),
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
    // Determine center icon size
    const double iconSize = 80;
    
    return Scaffold(
      backgroundColor: Colors.black, // Darken background for focus
      body: GestureDetector(
        onHorizontalDragUpdate: (details) {
            // Swipe right to pop
            if (details.delta.dx > 10) {
               Navigator.of(context).pop();
            }
        },
        child: Stack(
          children: [
             // Background Visualizer
             Positioned.fill(
                 child: ContextEngineView(
                     connectedDeviceOffsets: _sensorOffsets,
                     centerWidget: _buildCentralDeviceNode(iconSize),
                 ),
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
                                const SizedBox(height: 300), // Match Hub spacing
                                
                                // Sensor Grid (Mimicking Device Grid)
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.center, 
                                    children: widget.device.sensors.asMap().entries.map((entry) {
                                        final index = entry.key;
                                        final sensor = entry.value;
                                        return Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            child: _buildSensorItem(sensor, index),
                                        );
                                    }).toList(),
                                ),
                            ],
                        ),
                    ),
                    const Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: Center(
                            child: Text(
                                "Swipe Right to return",
                                style: TextStyle(color: AppColors.inactive, fontSize: 12),
                            ),
                        ),
                    ),
                ],
             ),
          ],
        ),
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
                          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                          widget.device.label.toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              fontSize: 16,
                          ),
                      ),
                      IconButton(
                          icon: const Icon(Icons.add, color: Colors.white),
                          onPressed: _showAddSensorOptions,
                      ),
                  ],
              ),
          ),
      );
  }

  Widget _buildCentralDeviceNode(double size) {
      final isConnected = widget.device.isConnected;
      final color = isConnected ? AppColors.neonGreen : AppColors.inactive;
      
      return GestureDetector(
          onTap: () {
              setState(() {
                  widget.device.isConnected = !widget.device.isConnected;
              });
          },
          child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: size + 40,
              height: size + 40,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  border: Border.all(color: color, width: 2),
                  boxShadow: isConnected ? [
                      BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                      )
                  ] : [],
              ),
              child: Icon(
                  widget.device.icon,
                  size: size,
                  color: color,
              ),
          ),
      );
  }


  Widget _buildSensorItem(SensorModel sensor, int index) {
      final isDeviceConnected = widget.device.isConnected;
      // If device is strictly off, sensor is visually off (grayed out).
      // If device is on, sensor shows its own state (connected=green, disconnected=blue/grey).
      
      final isSensorActive = isDeviceConnected && sensor.isConnected;
      // If device is disconnected, everything is inactive grey.
      // If device is connected but sensor is not, it's inactive blue (standby).
      final Color color = isDeviceConnected 
          ? (isSensorActive ? AppColors.neonGreen : AppColors.inactive)
          : AppColors.inactive.withValues(alpha: 0.3); // Dimmer if hard disabled
          
      return GestureDetector(
          onTap: isDeviceConnected ? () => _toggleSensor(index) : null,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                   AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      key: sensor.key, // KEY FOR TRACKING POSITION
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: color,
                              width: isSensorActive ? 2 : 1,
                          ),
                          boxShadow: isSensorActive ? [
                              BoxShadow(
                                  color: AppColors.neonGreen.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                              )
                          ] : [],
                      ),
                      child: Icon(
                          sensor.icon,
                          color: isDeviceConnected ? (isSensorActive ? Colors.white : AppColors.inactive) : AppColors.inactive.withValues(alpha: 0.5),
                          size: 24,
                      ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      sensor.label,
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                      ),
                  ),
              ],
          ),
      );
  }
}
