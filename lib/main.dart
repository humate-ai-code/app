import 'package:flutter/material.dart';
import 'package:flutter_app/screens/main_scaffold.dart';
import 'package:flutter_app/theme/app_theme.dart';

void main() {
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
