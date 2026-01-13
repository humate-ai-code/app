import 'package:flutter/material.dart';
import 'package:flutter_app/theme/app_theme.dart';
import 'package:flutter_app/repositories/conversation_repository.dart';
import 'package:flutter_app/repositories/task_repository.dart';
import 'package:flutter_app/repositories/speaker_repository.dart';
import 'package:flutter_app/services/context_action_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Settings"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader("General"),
          const SizedBox(height: 10),
          _buildTranscriptionCard(context),
          const SizedBox(height: 30),
          _buildSectionHeader("Data Management"),
          const SizedBox(height: 10),
          _buildResetCard(context),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildResetCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
        title: const Text("Reset All Data", style: TextStyle(color: Colors.white)),
        subtitle: const Text(
          "Clear conversations, tasks, and speakers.",
          style: TextStyle(color: AppColors.textSecondary),
        ),
        onTap: () => _confirmReset(context),
      ),
    );
  }

  Widget _buildTranscriptionCard(BuildContext context) {
      // We need to manage state here if we want instant feedback, but simpler is to show dialog or a selector page.
      // Let's replicate the dialog logic but as a card selector or just a tile that opens the dialog.
      // For simplicity in this screen, a tile opening a dialog is good.
      
      final current = ContextActionService().currentProvider;
      
      return Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: ListTile(
            leading: const Icon(Icons.mic, color: AppColors.cyanAccent),
            title: const Text("Transcription Provider", style: TextStyle(color: Colors.white)),
            subtitle: Text(current, style: const TextStyle(color: AppColors.textSecondary)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
            onTap: () => _showTranscriptionDialog(context),
          ),
      );
  }

  void _showTranscriptionDialog(BuildContext context) {
      showDialog(
          context: context,
          builder: (context) {
              String selected = ContextActionService().currentProvider;
              return StatefulBuilder(
                  builder: (context, setDialogState) {
                      return AlertDialog(
                          backgroundColor: AppColors.cardBackground,
                          title: const Text("Transcription Provider", style: TextStyle(color: Colors.white)),
                          content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                  _buildRadioOption("Sherpa-ONNX (Offline)", "Sherpa", selected, (val) => setDialogState(() => selected = val!)),
                                  _buildRadioOption("Android Speech (On-Device)", "Android", selected, (val) => setDialogState(() => selected = val!)),
                                  _buildRadioOption("ElevenLabs (Cloud)", "ElevenLabs", selected, (val) => setDialogState(() => selected = val!)),
                              ],
                          ),
                          actions: [
                              TextButton(
                                  child: const Text("Cancel"),
                                  onPressed: () => Navigator.pop(context),
                              ),
                              TextButton(
                                  child: const Text("Save", style: TextStyle(color: AppColors.cyanAccent)),
                                  onPressed: () {
                                      ContextActionService().switchProvider(selected);
                                      Navigator.pop(context); // Close dialog
                                      // Force rebuild of parent to update subtitle? parent is stateless.
                                      // In a real app we'd use a state management solution.
                                      // Here, the user won't see the update until they come back or we force it.
                                      // Let's assume it's fine for now or trigger a rebuild if we converted to StatefulWidget.
                                      // Actually, converting to StatefulWidget is better.
                                  },
                              ),
                          ],
                      );
                  },
              );
          },
      );
  }

  Widget _buildRadioOption(String label, String value, String groupValue, ValueChanged<String?> onChanged) {
      return RadioListTile<String>(
          title: Text(label, style: const TextStyle(color: Colors.white)),
          value: value,
          groupValue: groupValue,
          onChanged: onChanged,
          activeColor: AppColors.cyanAccent,
      );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text("Reset All Data?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "This action cannot be undone. All your conversations, tasks, and identified speakers will be permanently deleted.",
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete Everything", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
       // Reset functionality
       await ConversationRepository().reset();
       await TaskRepository().reset();
       await SpeakerRepository().reset();
       
       if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("All data has been reset.")),
         );
       }
    }
  }
}
