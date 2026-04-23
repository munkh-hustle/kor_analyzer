// lib/screens/text_input_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/korean_reader_provider.dart';
import '../widgets/analysis_result_widget.dart';
import '../widgets/dictionary_popup.dart';
import '../services/history_service.dart';
import 'history_screen.dart';

class TextInputScreen extends StatefulWidget {
  const TextInputScreen({super.key});

  @override
  State<TextInputScreen> createState() => _TextInputScreenState();
}

class _TextInputScreenState extends State<TextInputScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  bool _showResults = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _analyzeText() {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Шинжилгээ хийх текстийг оруулна уу.'),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() {
      _showResults = true;
    });

    final provider = Provider.of<KoreanReaderProvider>(context, listen: false);
    provider.analyzeText(_textController.text);
    _animationController.forward(from: 0);
    
    // Save to reading history
    HistoryService().saveHistory(_textController.text);
  }

  void _clearText() {
    _textController.clear();
    setState(() {
      _showResults = false;
    });
    Provider.of<KoreanReaderProvider>(context, listen: false).clearResults();
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Korean Reader',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
            tooltip: 'Түүх',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _clearText,
            tooltip: '초기화',
          ),
        ],
      ),
      body: Column(
        children: [
          // Input section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Солонгос текст оруулах',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Шинжилгээ хийх текстийг оруулна уу',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _textController,
                  maxLines: 6,
                  textInputAction: TextInputAction.newline,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                  decoration: InputDecoration(
                    hintText:
                        'Солонгос текстийг энд оруулах эсвэл буулгана уу...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.text_fields_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _clearText,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Устгах'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _analyzeText,
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: const Text('Шинжилгээ хийх'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                        ),
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
                  return _buildLoadingState(
                    context,
                    provider.errorMessage.isNotEmpty
                        ? provider.errorMessage
                        : '초기화 중...',
                  );
                }

                if (provider.isDatabaseLoading) {
                  return _buildDatabaseLoadingState(context, provider);
                }

                if (provider.isAnalyzing) {
                  return _buildLoadingState(context, 'шинжилгээ хийх...');
                }

                if (!_showResults || provider.currentResults.isEmpty) {
                  return _buildEmptyState(context);
                }

                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: AnalysisResultWidget(
                    results: provider.currentResults,
                    onWordTap: (word, tag) {
                      _showDefinition(context, word, tag, provider);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatabaseLoadingState(BuildContext context, KoreanReaderProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.download_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Толь бичиг ачааллаж байна...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Файл: ${provider.loadedFilesCount}/${provider.totalFilesCount}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Бичлэг: ${provider.totalEntriesLoaded}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: provider.databaseLoadingProgress,
                  minHeight: 8,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${(provider.databaseLoadingProgress * 100).toInt()}%',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.menu_book_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Текстийг оруулаад дүн шинжилгээ хийх товчийг дарна уу.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Өгүүлбэрийн шинжилгээ болон толь бичгийн хайлт хийх боломжтой..',
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showDefinition(BuildContext context, String word, String tag,
      KoreanReaderProvider provider) async {
    print('=== _showDefinition called for word=$word, tag=$tag ===');

    // First try with the original word
    var result = await provider.getDefinitionWithMultiLang(word, tag);

    // If no good result found, try combining with adjacent morphemes
    if (result == null || result['definition'] == null) {
      final combinedResult = await _tryCombinedWordSearch(word, tag, provider);
      if (combinedResult != null) {
        result = combinedResult;
      }
    }

    print(
        '=== _showDefinition received definition: ${result?['definition'] ?? "null"} ===');

    // If a matchedWord is returned (prefix match), show that in the popup
    final displayWord = result?['matchedWord'] as String? ?? word;

    // Unfocus any current focus to prevent keyboard from showing
    FocusScope.of(context).unfocus();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => DictionaryPopup(
        word: displayWord,
        tag: tag,
        definition: result?['definition'] as String?,
        multilanListJson: result?['multilanList'] as String?,
        fullSenseInfoJson: result?['fullSenseInfo'] as String?,
        gubun: result?['gubun'] as String?,
      ),
    );
  }

  Future<Map<String, dynamic>?> _tryCombinedWordSearch(
      String word, String tag, KoreanReaderProvider provider) async {
    // Get current analysis results to find adjacent morphemes
    final results = provider.currentResults;
    if (results.isEmpty) return null;

    // Find the index of the current word in results
    int currentIndex = -1;
    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      for (var morph in result.morphemes) {
        if (morph.text == word && morph.tag == tag) {
          currentIndex = i;
          break;
        }
      }
      if (currentIndex >= 0) break;
    }

    if (currentIndex < 0 || currentIndex >= results.length - 1) return null;

    // Try combining with next morpheme(s)
    final currentResult = results[currentIndex];
    final currentMorphIndex = currentResult.morphemes
        .indexWhere((m) => m.text == word && m.tag == tag);

    if (currentMorphIndex < 0 ||
        currentMorphIndex >= currentResult.morphemes.length - 1) return null;

    // Combine current + next morpheme
    final nextMorph = currentResult.morphemes[currentMorphIndex + 1];
    final combinedWord = word + nextMorph.text;
    final combinedTag = tag; // Use first morpheme's tag

    print('=== Trying combined word search: $combinedWord ($tag) ===');
    return await provider.getDefinitionWithMultiLang(combinedWord, combinedTag);
  }
}
