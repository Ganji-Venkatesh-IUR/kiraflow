import 'package:flutter/material.dart';
import 'screens/upload_screen.dart';

void main() => runApp(const KiraFlowApp());

class KiraFlowApp extends StatelessWidget {
  const KiraFlowApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KiraFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1D9E75)),
        useMaterial3: true,
      ),
      home: const UploadScreen(),
    );
  }
}
