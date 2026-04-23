// lib/screens/flashcard_review_screen.dart
import 'package:flutter/material.dart';
import '../models/flashcard.dart';
import '../services/flashcard_service.dart';
import '../services/history_service.dart';

class FlashcardReviewScreen extends StatefulWidget {
  const FlashcardReviewScreen({super.key});

  @override
  State<FlashcardReviewScreen> createState() => _FlashcardReviewScreenState();
}

class _FlashcardReviewScreenState extends State<FlashcardReviewScreen> {
  final FlashcardService _flashcardService = FlashcardService();
  late Future<List<Flashcard>> _dueCardsFuture;
  List<Flashcard> _reviewQueue = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _isComplete = false;
  
  // Statistics
  int _correctCount = 0;
  int _incorrectCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDueCards();
  }

  Future<void> _loadDueCards() async {
    setState(() {
      _dueCardsFuture = _flashcardService.getDueFlashcards(limit: 20);
    });
    
    final cards = await _dueCardsFuture;
    if (cards.isEmpty) {
      setState(() {
        _isComplete = true;
      });
    } else {
      setState(() {
        _reviewQueue = cards;
      });
    }
  }

  void _showAnswerCard() {
    setState(() {
      _showAnswer = true;
    });
  }

  Future<void> _rateCard(int quality) async {
    if (_currentIndex >= _reviewQueue.length) return;
    
    final currentCard = _reviewQueue[_currentIndex];
    
    try {
      await _flashcardService.updateFlashcardAfterReview(
        currentCard.id,
        quality,
      );
      
      if (quality >= 3) {
        setState(() {
          _correctCount++;
        });
      } else {
        setState(() {
          _incorrectCount++;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Алдаа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    
    setState(() {
      _currentIndex++;
      _showAnswer = false;
      
      if (_currentIndex >= _reviewQueue.length) {
        _isComplete = true;
      }
    });
  }

  void _restartSession() {
    setState(() {
      _currentIndex = 0;
      _showAnswer = false;
      _isComplete = false;
      _correctCount = 0;
      _incorrectCount = 0;
    });
    _loadDueCards();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Flashcard Review',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_isComplete && _reviewQueue.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  '${_currentIndex + 1}/${_reviewQueue.length}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: FutureBuilder<List<Flashcard>>(
        future: _dueCardsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Алдаа гарлаа: ${snapshot.error}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            );
          }

          if (_isComplete || _reviewQueue.isEmpty) {
            return _buildCompletionScreen();
          }

          final flashcard = _reviewQueue[_currentIndex];
          return _buildReviewCard(flashcard);
        },
      ),
    );
  }

  Widget _buildCompletionScreen() {
    final totalCards = _correctCount + _incorrectCount;
    final accuracy = totalCards > 0 
        ? (_correctCount / totalCards * 100).round() 
        : 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.celebration_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Сайн байна!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Та энэ удаагийн давталтаа дуусгалаа.',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Зөв',
                  value: _correctCount.toString(),
                  color: Colors.green,
                ),
                _buildStatCard(
                  icon: Icons.cancel_outlined,
                  label: 'Буруу',
                  value: _incorrectCount.toString(),
                  color: Colors.red,
                ),
                _buildStatCard(
                  icon: Icons.percent_rounded,
                  label: 'Нарийвчлал',
                  value: '$accuracy%',
                  color: Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (_reviewQueue.isNotEmpty)
              ElevatedButton.icon(
                onPressed: _restartSession,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Дахин эхлүүлэх'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Буцах'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Flashcard flashcard) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _reviewQueue.length,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 24),
          
          // Card container
          Container(
            constraints: const BoxConstraints(minHeight: 300),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Context paragraph section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.contextual_token_rounded,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Контекст',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        flashcard.paragraph,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Word section
                Column(
                  children: [
                    Text(
                      flashcard.word,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        flashcard.tag,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Answer section
                if (_showAnswer) ...[
                  AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 18,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Тодорхойлолт',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (flashcard.definition != null && flashcard.definition!.isNotEmpty)
                            Text(
                              flashcard.definition!,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: Theme.of(context).colorScheme.onSecondaryContainer,
                              ),
                            )
                          else
                            Text(
                              'Тодорхойлолт байхгүй',
                              style: TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.7),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 80), // Placeholder for answer area
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Action buttons
          if (!_showAnswer) {
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showAnswerCard,
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('Хариултыг харах'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            );
          } else {
            Column(
              children: [
                const Text(
                  'Хэр сайн санаж байна вэ?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildRatingButton(
                      label: 'Дахин',
                      quality: 1,
                      color: Colors.red,
                      subtitle: '< 1м',
                    ),
                    _buildRatingButton(
                      label: 'Хэцүү',
                      quality: 3,
                      color: Colors.orange,
                      subtitle: '2 өдөр',
                    ),
                    _buildRatingButton(
                      label: 'Сайн',
                      quality: 4,
                      color: Colors.blue,
                      subtitle: '4 өдөр',
                    ),
                    _buildRatingButton(
                      label: 'Хялбар',
                      quality: 5,
                      color: Colors.green,
                      subtitle: '7 өдөр',
                    ),
                  ],
                ),
              ],
            );
          },
        ],
      ),
    );
  }

  Widget _buildRatingButton({
    required String label,
    required int quality,
    required Color color,
    required String subtitle,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () => _rateCard(quality),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
