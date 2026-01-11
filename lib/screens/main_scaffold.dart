import 'package:flutter/material.dart';
import 'package:flutter_app/screens/conversations_screen.dart';
import 'package:flutter_app/screens/device_hub_screen.dart';
import 'package:flutter_app/screens/tasks_screen.dart';
import 'package:flutter_app/theme/app_theme.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 1; // Default to Hub

  final List<Widget> _screens = const [
    ConversationsScreen(),
    DeviceHubScreen(),
    TasksScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Important for glassmorphism over content
      body: _screens[_currentIndex],
      bottomNavigationBar: _buildBottomDock(),
    );
  }

  Widget _buildBottomDock() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30, left: 24, right: 24),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: AppColors.cardBackground.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(35),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDockItem(Icons.chat_bubble_outline, 0),
              _buildCenterButton(),
              _buildDockItem(Icons.check_circle_outline, 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterButton() {
    final isSelected = _currentIndex == 1;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = 1),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? Colors.white : Colors.black,
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.3),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ] : [],
        ),
        child: Center(
          child: Text(
            "C&C",
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDockItem(IconData icon, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        color: Colors.transparent, // Hit test target
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          size: 28,
          color: isSelected ? Colors.white : AppColors.inactive,
        ),
      ),
    );
  }
}
