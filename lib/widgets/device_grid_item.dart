import 'package:flutter/material.dart';
import 'package:flutter_app/theme/app_theme.dart';

class DeviceGridItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isConnected;
  final VoidCallback onTap;

  const DeviceGridItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isConnected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isConnected ? AppColors.neonGreen.withValues(alpha: 0.1) : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isConnected ? AppColors.neonGreen : AppColors.inactive,
                width: 2,
              ),
              boxShadow: isConnected
                  ? [
                      BoxShadow(
                        color: AppColors.neonGreen.withValues(alpha: 0.4),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: Icon(
              icon,
              size: 32,
              color: isConnected ? AppColors.neonGreen : AppColors.inactive,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            isConnected ? 'wired in' : 'tap to wire in',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isConnected ? AppColors.neonGreen : AppColors.textSecondary,
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );
  }
}
