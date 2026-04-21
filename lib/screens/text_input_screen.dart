// lib/screens/text_input_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/korean_reader_provider.dart';
import '../widgets/analysis_result_widget.dart';
import '../widgets/dictionary_popup.dart';

class TextInputScreen extends StatefulWidget {
  const TextInputScreen({super.key});

  @override
  State<TextInputScreen> createState() => _TextInputScreenState();
}

class _TextInputScreenState extends State<TextInputScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _showResults = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _analyzeText() {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('분석할 텍스트를 입력해주세요.')),
      );
      return;
    }
    
    setState(() {
      _showResults = true;
    });
    
    final provider = Provider.of<KoreanReaderProvider>(context, listen: false);
    provider.analyzeText(_textController.text);
  }

  void _clearText() {
    _textController.clear();
    setState(() {
      _showResults = false;
    });
    Provider.of<KoreanReaderProvider>(context, listen: false).clearResults();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Korean Reader'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearText,
            tooltip: '모두 지우기',
          ),
        ],
      ),
      body: Column(
        children: [
          // Input section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '한국어 텍스트 입력',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _textController,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: '여기에 한국어 텍스트를 입력하거나 붙여넣으세요...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _analyzeText,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('분석하기'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _clearText,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('지우기'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Analysis results section
          Expanded(
            child: Consumer<KoreanReaderProvider>(
              builder: (context, provider, child) {
                if (!provider.isInitialized) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          provider.errorMessage.isNotEmpty
                              ? provider.errorMessage
                              : '초기화 중...',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  );
                }
                
                if (provider.isAnalyzing) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('분석 중...'),
                      ],
                    ),
                  );
                }
                
                if (!_showResults || provider.currentResults.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.text_fields,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '텍스트를 입력하고 분석 버튼을 눌러주세요.',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }
                
                return AnalysisResultWidget(
                  results: provider.currentResults,
                  onWordTap: (word, tag) {
                    _showDefinition(context, word, tag, provider);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDefinition(BuildContext context, String word, String tag, 
      KoreanReaderProvider provider) async {
    print('=== _showDefinition called for word=$word, tag=$tag ===');
    final result = await provider.getDefinitionWithMultiLang(word, tag);
    print('=== _showDefinition received definition: ${result?['definition'] ?? "null"} ===');
    
    showDialog(
      context: context,
      builder: (context) => DictionaryPopup(
        word: word,
        tag: tag,
        definition: result?['definition'] as String?,
        multilanListJson: result?['multilanList'] as String?,
      ),
    );
  }
}