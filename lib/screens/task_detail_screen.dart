import 'package:flutter/material.dart';
import 'package:flutter_app/models/task_model.dart';
import 'package:flutter_app/screens/conversation_detail_screen.dart';
import 'package:flutter_app/repositories/conversation_repository.dart';
import 'package:flutter_app/theme/app_theme.dart';
import 'package:intl/intl.dart';

class TaskDetailScreen extends StatelessWidget {
  final Task task;

  const TaskDetailScreen({required this.task, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mission Detail'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildInfoCard(),
            const SizedBox(height: 24),
            if (task.sourceConversationId != null) _buildSourceButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Row(
           children: [
               Icon(task.isCompleted ? Icons.check_circle : Icons.circle_outlined, 
                 color: task.isCompleted ? AppColors.neonGreen : AppColors.textSecondary,
                 size: 20
               ),
               const SizedBox(width: 8),
               Text(
                 task.status.toUpperCase(),
                 style: TextStyle(
                   color: task.isCompleted ? AppColors.neonGreen : AppColors.textSecondary,
                   fontWeight: FontWeight.bold,
                   letterSpacing: 1.2
                 ),
               ),
           ],
        )
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task.dueDate != null) ...[
            _buildLabel("DUE DATE"),
            Text(
              DateFormat('yyyy-MM-dd HH:mm').format(task.dueDate!),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const Divider(color: Colors.white24, height: 32),
          ],
          
          _buildLabel("DESCRIPTION"),
          Text(
            task.description.isEmpty ? "No detailed instructions provided." : task.description,
            style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSourceButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
            _navigateToSource(context);
        },
        icon: const Icon(Icons.record_voice_over, color: Colors.black),
        label: const Text("JUMP TO SOURCE CONVERSATION"),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cyanAccent,

          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
  
  void _navigateToSource(BuildContext context) {
      if (task.sourceConversationId == null) return;
      
      final thread = ConversationRepository().currentThreads.firstWhere(
          (t) => t.id == task.sourceConversationId,
          orElse: () => ConversationRepository().activeThread != null && ConversationRepository().activeThread!.id == task.sourceConversationId 
            ? ConversationRepository().activeThread!
            : throw "Conversation not found" // Handle gracefully in real app
      );
      
      // We pass the message ID to highlight/scroll to
      Navigator.push(
          context, 
          MaterialPageRoute(
              builder: (_) => ConversationDetailScreen(
                  thread: thread,
                  initialMessageId: task.sourceMessageId
              )
          )
      );
  }
}
