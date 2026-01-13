import 'package:flutter/material.dart';
import 'package:flutter_app/screens/main_scaffold.dart';
import 'package:flutter_app/theme/app_theme.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_app/services/gemini_analysis_service.dart';
import 'package:flutter_app/repositories/conversation_repository.dart';
import 'package:flutter_app/repositories/task_repository.dart';
import 'package:flutter_app/repositories/speaker_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  // Initialize services
  await SpeakerRepository().init();
  await ConversationRepository().init();
  await TaskRepository().init();
  await GeminiAnalysisService().init();
  
  runApp(const IntelligenceCenterApp());
}

class IntelligenceCenterApp extends StatelessWidget {
  const IntelligenceCenterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Intelligence Center',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainScaffold(),
    );
  }
}
