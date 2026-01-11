import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_app/models/device_model.dart';
import 'package:flutter_app/theme/app_theme.dart';
import 'package:flutter_app/widgets/context_engine_view.dart';
import 'package:flutter_app/widgets/device_grid_item.dart';

class DeviceHubScreen extends StatefulWidget {
  const DeviceHubScreen({super.key});

  @override
  State<DeviceHubScreen> createState() => _DeviceHubScreenState();
}

class _DeviceHubScreenState extends State<DeviceHubScreen> {
  // Device List
  final List<DeviceModel> _devices = [
    DeviceModel(id: 'phone', icon: Icons.smartphone, label: 'Phone', isConnected: true),
    DeviceModel(id: 'watch', icon: Icons.watch, label: 'Watch', isConnected: false),
    DeviceModel(id: 'buds', icon: Icons.headphones, label: 'Earbuds', isConnected: true),
  ];

  List<Offset> _connectedOffsets = [];

  @override
  void initState() {
    super.initState();
    // Schedule initial position check after layout
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _updateConnectionOffsets();
    });
  }

  void _toggleDevice(int index) {
    setState(() {
      _devices[index].isConnected = !_devices[index].isConnected;
    });
    // Give time for animation/layout if needed, though simple state change doesn't move widgets 
    // usually. But let's trigger update.
    // We wait one frame to ensure visual state is settled if it affects layout (it doesn't here, strictly, but good practice).
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _updateConnectionOffsets();
    });
  }

  void _updateConnectionOffsets() {
    final List<Offset> newOffsets = [];
    
    // We also need the position of the ContextEngineView relative to the overlay 
    // to map coordinates correctly if we were drawing globally.
    // However, our ContextEngineView is in a Stack filling the screen.
    // So if we find the global position of the device point, and convert it 
    // to the local coordinate system of the ContextEngineView (which is fullscreen), 
    // it should match.

    for (final device in _devices) {
      if (device.isConnected && device.key.currentContext != null) {
        final RenderBox box = device.key.currentContext!.findRenderObject() as RenderBox;
        final Offset center = box.localToGlobal(box.size.center(Offset.zero));
        
        // Pass global coordinate. ContextEngineView is fullscreen in stack, so global ~ local.
        // (Assuming standard Scaffold body starting top-left or similar).
        // To be safe, we can convert it to the coordinate space of the ContextEngineView if we had a key for it.
        // For now, assuming Full Screen Stack so Global == Local.
        newOffsets.add(center);
      }
    }

    setState(() {
      _connectedOffsets = newOffsets;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Logic: 
          // 1. We render the layout.
          // 2. We put ContextEngineView BEHIND the content or ON TOP?
          // If ON TOP, it blocks clicks. If BEHIND, lines go under widgets.
          // Lines under widgets is usually better looking for "plugging in".
          // BUT, we want lines to go into the Engine.
          
          // Let's do:
          // BACKGROUND: Gradient/Color
          // LAYER 1: ContextEngineView (The Engine + Lines) (Ignoring hits so clicks pass through?)
          // LAYER 2: Foreground Content (Text, Device Grid)
          
          // Actually, ContextEngineView needs to be aware of where things are.
          // We can put it in the background of the stack.
          
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
                           // Spacer to push Grid down away from Engine (which is centered)
                           // Engine is centered in the Stack/View.
                           // We need to make sure we don't cover it?
                           // Actually the Engine is drawn by ContextEngineView.
                           // We just need the Grid to be positioned where we want it.
                           
                           // Let's rely on the background view to draw the engine.
                           // We just put empty space here.
                           const SizedBox(height: 300), 
                           
                           // Device Grid
                           Row(
                               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                               children: _devices.asMap().entries.map((entry) {
                                   final index = entry.key;
                                   final device = entry.value;
                                   return DeviceGridItem(
                                       key: device.key, // Assign GlobalKey
                                       icon: device.icon,
                                       label: device.label,
                                       isConnected: device.isConnected,
                                       onTap: () => _toggleDevice(index),
                                   );
                               }).toList(),
                           ),
                       ],
                   ),
               ),
            ],
          ),
          
          // Bottom Dock - Removed as it is now in MainScaffold
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
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }


}
