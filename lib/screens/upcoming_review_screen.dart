// lib/screens/upcoming_review_screen.dart
import 'package:flutter/material.dart';
import '../models/flashcard.dart';
import '../services/flashcard_service.dart';

class UpcomingReviewScreen extends StatefulWidget {
  const UpcomingReviewScreen({super.key});

  @override
  State<UpcomingReviewScreen> createState() => _UpcomingReviewScreenState();
}

class _UpcomingReviewScreenState extends State<UpcomingReviewScreen> {
  final FlashcardService _flashcardService = FlashcardService();
  
  late Future<List<Flashcard>> _allCardsFuture;
  
  @override
  void initState() {
    super.initState();
    _allCardsFuture = _flashcardService.getAllFlashcards();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Ирэх өдрүүдийн давталт',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<List<Flashcard>>(
        future: _allCardsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded, size: 64, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text('Алдаа гарлаа: ${snapshot.error}', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ),
            );
          }
          
          final allCards = snapshot.data ?? [];
          
          if (allCards.isEmpty) {
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
                      Icons.event_busy_rounded,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Давталт байхгүй байна.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Шинэ үг нэмсний дараа энд хуваарь харагдана.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }
          
          // Group cards by review date
          final groupedCards = _groupCardsByDate(allCards);
          final sortedDates = groupedCards.keys.toList()..sort((a, b) => a.compareTo(b));
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Card
                _buildSummaryCard(context, allCards),
                
                const SizedBox(height: 24),
                
                // Upcoming Reviews List
                Text(
                  'Ирэх давталтууд',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedDates.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final date = sortedDates[index];
                    final cards = groupedCards[date]!;
                    return _buildDayCard(context, date, cards);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Map<DateTime, List<Flashcard>> _groupCardsByDate(List<Flashcard> cards) {
    final Map<DateTime, List<Flashcard>> grouped = {};
    
    for (var card in cards) {
      // Normalize to start of day
      final reviewDate = DateTime(
        card.nextReviewAt.year,
        card.nextReviewAt.month,
        card.nextReviewAt.day,
      );
      
      if (!grouped.containsKey(reviewDate)) {
        grouped[reviewDate] = [];
      }
      grouped[reviewDate]!.add(card);
    }
    
    return grouped;
  }

  Widget _buildSummaryCard(BuildContext context, List<Flashcard> allCards) {
    final now = DateTime.now();
    final dueToday = allCards.where((c) => c.nextReviewAt.isBefore(now.add(const Duration(days: 1))) && 
                                           c.nextReviewAt.isAfter(now.subtract(const Duration(days: 1)))).length;
    final dueThisWeek = allCards.where((c) => 
      c.nextReviewAt.isBefore(now.add(const Duration(days: 7))) && 
      c.nextReviewAt.isAfter(now)).length;
    final totalCards = allCards.length;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.secondary,
            Theme.of(context).colorScheme.tertiary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Нийт карт',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$totalCards',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  context,
                  label: 'Өнөөдөр',
                  value: dueToday.toString(),
                  icon: Icons.today_rounded,
                  color: Colors.orange,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.3),
              ),
              Expanded(
                child: _buildSummaryItem(
                  context,
                  label: 'Энэ долоо хоногт',
                  value: dueThisWeek.toString(),
                  icon: Icons.date_range_rounded,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildDayCard(BuildContext context, DateTime date, List<Flashcard> cards) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isTomorrow = date.isAfter(now) && date.difference(now).inDays == 1;
    final isPastDue = date.isBefore(now);
    
    String dateLabel;
    if (isToday) {
      dateLabel = 'Өнөөдөр';
    } else if (isTomorrow) {
      dateLabel = 'Маргааш';
    } else {
      dateLabel = _formatDate(date);
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPastDue 
              ? Theme.of(context).colorScheme.error.withOpacity(0.3)
              : Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: isPastDue ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isPastDue 
                  ? Theme.of(context).colorScheme.errorContainer
                  : isToday 
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(
                  isPastDue ? Icons.schedule_send_rounded : Icons.event_rounded,
                  color: isPastDue 
                      ? Theme.of(context).colorScheme.onErrorContainer
                      : isToday 
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSecondaryContainer,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isPastDue 
                              ? Theme.of(context).colorScheme.onErrorContainer
                              : isToday 
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSecondaryContainer,
                        ),
                      ),
                      Text(
                        '${cards.length} карт давтах',
                        style: TextStyle(
                          fontSize: 13,
                          color: isPastDue 
                              ? Theme.of(context).colorScheme.onErrorContainer.withOpacity(0.8)
                              : isToday 
                                  ? Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8)
                                  : Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isPastDue)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Хоцорсон',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Cards List
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: cards.take(5).map((card) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: card.isDue 
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              card.word,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (card.definition != null && card.definition!.isNotEmpty)
                              Text(
                                card.definition!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          card.tag,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Show more indicator
          if (cards.length > 5)
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
              child: Text(
                '+${cards.length - 5} илүү карт',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['', '1 сар', '2 сар', '3 сар', '4 сар', '5 сар', '6 сар', 
                    '7 сар', '8 сар', '9 сар', '10 сар', '11 сар', '12 сар'];
    const weekdays = ['Бямба', 'Ням', 'Даваа', 'Мягмар', 'Лхагва', 'Пүрэв', 'Баасан'];
    
    return '${weekdays[date.weekday % 7]}, ${months[date.month]} ${date.day}';
  }
}
