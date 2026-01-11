import 'package:flutter/material.dart';
import 'package:flutter_app/theme/app_theme.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mission Tasks'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTaskItem(
            'Upload Daily Logs',
            'Pending verification',
            false,
          ),
          _buildTaskItem(
            'Calibrate Sensors',
            'Completed successfully',
            true,
          ),
          _buildTaskItem(
            'Secure Channel Sync',
            'Key rotation required',
            false,
            isCritical: true,
          ),
          _buildTaskItem(
            'Archive Old Signals',
            'Scheduled for 0400',
            false,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(String title, String status, bool isCompleted, {bool isCritical = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted 
            ? AppColors.neonGreen.withValues(alpha: 0.3) 
            : (isCritical ? AppColors.purpleAccent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : (isCritical ? Icons.warning_amber_rounded : Icons.circle_outlined),
            color: isCompleted ? AppColors.neonGreen : (isCritical ? AppColors.purpleAccent : AppColors.textSecondary),
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isCompleted ? AppColors.textSecondary : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: TextStyle(
                    color: isCritical ? AppColors.purpleAccent : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
