// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/korean_reader_provider.dart';
import 'screens/text_input_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KoreanReaderApp());
}

class KoreanReaderApp extends StatelessWidget {
  const KoreanReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => KoreanReaderProvider(),
      child: MaterialApp(
        title: 'Korean Reader',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const TextInputScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}