import 'package:flutter/material.dart';
import 'package:flutter_app/models/conversation_model.dart';
import 'package:flutter_app/screens/conversation_detail_screen.dart';
import 'package:flutter_app/services/conversation_repository.dart';
import 'package:flutter_app/theme/app_theme.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<ConversationThread>>(
        stream: ConversationRepository().threadsStream,
        initialData: ConversationRepository().currentThreads,
        builder: (context, snapshot) {
          final threads = snapshot.data ?? [];
          
          if (threads.isEmpty) {
             return Center(
               child: Text(
                 'No conversations yet',
                 style: TextStyle(color: AppColors.textSecondary),
               ),
             );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: threads.length,
            itemBuilder: (context, index) {
              final thread = threads[index];
              return _buildThreadItem(thread);
            },
          );
        },
      ),
    );
  }

  Widget _buildThreadItem(ConversationThread thread) {
    final lastMessage = thread.summary != null 
        ? "Summary: ${thread.summary}" 
        : (thread.messages.isNotEmpty ? thread.messages.last.text : 'Empty Session');
    
    final isSummary = thread.summary != null;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ConversationDetailScreen(thread: thread)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: thread.isActive ? AppColors.cyanAccent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: thread.isActive ? AppColors.cyanAccent : AppColors.cardBackground,
              child: Icon(
                thread.isActive ? Icons.mic : Icons.history,
                color: thread.isActive ? Colors.black : Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(thread.startTime),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage,
                    style: TextStyle(
                      color: isSummary ? AppColors.purpleAccent : AppColors.textSecondary,
                      fontSize: 14,
                      fontStyle: isSummary ? FontStyle.italic : FontStyle.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (thread.isUnread) ...[
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
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
