// lib/widgets/analysis_result_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/analysis_result.dart';
import '../services/flashcard_service.dart';
import '../providers/korean_reader_provider.dart';

class AnalysisResultWidget extends StatelessWidget {
  final List<AnalysisResult> results;
  final Function(String word, String tag) onWordTap;
  final String? paragraphId; // Added to link flashcards to history entry
  final String paragraphText; // The full paragraph text

  const AnalysisResultWidget({
    super.key,
    required this.results,
    required this.onWordTap,
    this.paragraphId,
    required this.paragraphText,
  });

  void _addToFlashcards(BuildContext context, String word, String tag) async {
    if (paragraphId == null) return;
    
    final flashcardService = FlashcardService();
    
    // Check if already exists
    final exists = await flashcardService.exists(paragraphId!, word);
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Энэ үг нь аль хэдийн лавлагаанд байна.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    // Show loading indicator while fetching definition
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    try {
      // Fetch definition from dictionary using the provider from context
      final provider = Provider.of<KoreanReaderProvider>(context, listen: false);
      final result = await provider.getDefinitionWithMultiLang(word, tag);
      final definition = result?['definition'] as String?;
      
      // Create flashcard with definition
      await flashcardService.createFlashcard(
        paragraphId: paragraphId!,
        paragraph: paragraphText,
        word: word,
        tag: tag,
        definition: definition,
      );
      
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Text('$word - Flashcard үүсгэв'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Алдаа: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bar showing result count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.analytics_rounded,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '분석 결과 ${results.length}개',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          // Results list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final result = results[index];
                return _buildResultCard(context, result, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(
      BuildContext context, AnalysisResult result, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with index and original form
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${result.index}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.originalForm,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '형태소 ${result.morphemes.length}개',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Divider
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey[200],
            ),
            const SizedBox(height: 12),
            
            // Morphemes section header
            Row(
              children: [
                Icon(
                  Icons.apps_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '형태소 분석',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // Morphemes chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.morphemes.map((morpheme) {
                return _buildMorphemeChip(context, morpheme);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMorphemeChip(BuildContext context, Morpheme morpheme) {
    final colorScheme = Theme.of(context).colorScheme;
    final tagColor = _getTagColor(morpheme.tag, colorScheme);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          onWordTap(morpheme.text, morpheme.tag);
          // Add long-press or double-tap to add to flashcards
        },
        onLongPress: () => _addToFlashcards(context, morpheme.text, morpheme.tag),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: tagColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: tagColor.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                morpheme.text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tagColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  morpheme.tag,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.add_circle_outline_rounded,
                size: 14,
                color: tagColor.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTagColor(String tag, ColorScheme colorScheme) {
    // Categorize tags by type and assign colors
    if (tag.startsWith('NN') || tag == 'NP' || tag == 'NR') {
      // Nouns - Blue
      return colorScheme.primary;
    } else if (tag.startsWith('V')) {
      // Verbs/Adjectives - Green
      return Colors.green.shade600;
    } else if (tag.startsWith('J')) {
      // Particles - Orange
      return Colors.orange.shade600;
    } else if (tag.startsWith('E')) {
      // Endings - Purple
      return Colors.purple.shade600;
    } else if (tag.startsWith('X')) {
      // Affixes - Teal
      return Colors.teal.shade600;
    } else if (tag.startsWith('M')) {
      // Modifiers - Pink
      return Colors.pink.shade600;
    } else {
      // Others - Grey
      return Colors.grey.shade600;
    }
  }
}