import 'package:flutter/material.dart';
import 'package:flutter_app/theme/app_theme.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildConversationItem(
            'Agent Smith',
            'Target acquired. Awaiting instructions.',
            '2m ago',
          ),
          _buildConversationItem(
            'HQ',
            'Update: New encryption keys available.',
            '1h ago',
            isUnread: true,
          ),
          _buildConversationItem(
            'Ops Team',
            'Status report: Sector 7 clear.',
            '3h ago',
          ),
          _buildConversationItem(
            'Analyst 04',
            'Data anomaly detected in signal stream.',
            '1d ago',
          ),
        ],
      ),
    );
  }

  Widget _buildConversationItem(String name, String preview, String time, {bool isUnread = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread ? AppColors.cyanAccent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isUnread ? AppColors.cyanAccent : AppColors.cardBackground,
            child: Text(
              name[0],
              style: TextStyle(
                color: isUnread ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  preview,
                  style: TextStyle(
                    color: isUnread ? Colors.white : AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isUnread) ...[
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.neonGreen,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
