// lib/screens/streak_stats_screen.dart
import 'package:flutter/material.dart';
import '../services/history_service.dart';
import '../services/flashcard_service.dart';
import '../models/reading_history.dart';
import 'dart:collection';

class StreakStatsScreen extends StatefulWidget {
  const StreakStatsScreen({super.key});

  @override
  State<StreakStatsScreen> createState() => _StreakStatsScreenState();
}

class _StreakStatsScreenState extends State<StreakStatsScreen> {
  final HistoryService _historyService = HistoryService();
  final FlashcardService _flashcardService = FlashcardService();
  
  late Future<StreakData> _streakDataFuture;
  
  @override
  void initState() {
    super.initState();
    _streakDataFuture = _calculateStreakData();
  }

  Future<StreakData> _calculateStreakData() async {
    final history = await _historyService.getHistory();
    final flashcards = await _flashcardService.getAllFlashcards();
    
    // Group history entries by date
    final Map<String, int> wordsPerDay = {};
    for (var entry in history) {
      final dateKey = _formatDateKey(entry.timestamp);
      wordsPerDay[dateKey] = (wordsPerDay[dateKey] ?? 0) + entry.wordCount;
    }
    
    // Calculate current streak
    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 0;
    
    final sortedDates = wordsPerDay.keys.toList()..sort((a, b) => b.compareTo(a));
    final today = _formatDateKey(DateTime.now());
    
    // Check if user studied today or yesterday to maintain streak
    bool hasActivityToday = wordsPerDay.containsKey(today);
    bool hasActivityYesterday = false;
    
    if (!hasActivityToday && sortedDates.isNotEmpty) {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      hasActivityYesterday = wordsPerDay.containsKey(_formatDateKey(yesterday));
    }
    
    // Calculate current streak
    DateTime checkDate = hasActivityToday ? DateTime.now() : DateTime.now().subtract(const Duration(days: 1));
    
    while (true) {
      final dateKey = _formatDateKey(checkDate);
      if (wordsPerDay.containsKey(dateKey)) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    
    // Calculate longest streak
    if (sortedDates.isNotEmpty) {
      DateTime? previousDate;
      for (var dateKey in sortedDates.reversed()) {
        final currentDate = _parseDateKey(dateKey);
        if (previousDate == null) {
          tempStreak = 1;
        } else {
          final diff = currentDate.difference(previousDate).inDays;
          if (diff == 1) {
            tempStreak++;
          } else if (diff > 1) {
            if (tempStreak > longestStreak) {
              longestStreak = tempStreak;
            }
            tempStreak = 1;
          }
        }
        previousDate = currentDate;
      }
      if (tempStreak > longestStreak) {
        longestStreak = tempStreak;
      }
    }
    
    // Get last 7 days activity
    final last7Days = <DayActivity>[];
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateKey = _formatDateKey(date);
      final wordCount = wordsPerDay[dateKey] ?? 0;
      last7Days.add(DayActivity(
        date: date,
        wordCount: wordCount,
        hasActivity: wordCount > 0,
      ));
    }
    
    // Calculate total words learned
    int totalWords = flashcards.length;
    int totalReviews = flashcards.fold<int>(0, (sum, card) => sum + card.repetitions);
    
    return StreakData(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      last7Days: last7Days,
      totalWords: totalWords,
      totalReviews: totalReviews,
      wordsPerDay: SplayTreeMap.from(wordsPerDay),
    );
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  DateTime _parseDateKey(String key) {
    final parts = key.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Өдрийн цуврал',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<StreakData>(
        future: _streakDataFuture,
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
          
          final data = snapshot.data!;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current Streak Card
                _buildStreakCard(context, data),
                
                const SizedBox(height: 24),
                
                // Weekly Activity Chart
                _buildWeeklyActivityChart(context, data),
                
                const SizedBox(height: 24),
                
                // Statistics Summary
                _buildStatsSummary(context, data),
                
                const SizedBox(height: 24),
                
                // Words History
                _buildWordsHistory(context, data),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStreakCard(BuildContext context, StreakData data) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Өдрийн цуврал',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${data.currentStreak}',
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'өдөр',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyActivityChart(BuildContext context, StreakData data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_view_week_rounded, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                'Долоо хоногийн идэвх',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.last7Days.map((day) {
              final maxWords = data.last7Days.map((d) => d.wordCount).reduce((a, b) => a > b ? a : b);
              final height = maxWords > 0 ? (day.wordCount / maxWords * 100).clamp(10.0, 100.0) : 10.0;
              
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${day.wordCount}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 32,
                    height: 100,
                    decoration: BoxDecoration(
                      color: day.hasActivity 
                          ? Theme.of(context).colorScheme.primary 
                          : Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: height,
                        decoration: BoxDecoration(
                          color: day.hasActivity 
                              ? Theme.of(context).colorScheme.primary 
                              : Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getDayAbbreviation(day.date.weekday),
                    style: TextStyle(
                      fontSize: 12,
                      color: day.hasActivity 
                          ? Theme.of(context).colorScheme.primary 
                          : Theme.of(context).colorScheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary(BuildContext context, StreakData data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                'Нийт статистик',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: Icons.auto_graph_rounded,
                  label: 'Хамгийн урт\ncуварал',
                  value: '${data.longestStreak}',
                  unit: 'өдөр',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: Icons.menu_book_rounded,
                  label: 'Нийт үгс',
                  value: '${data.totalWords}',
                  unit: 'үг',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: Icons.repeat_rounded,
                  label: 'Нийт давталт',
                  value: '${data.totalReviews}',
                  unit: 'удаа',
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required String unit,
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
            unit,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordsHistory(BuildContext context, StreakData data) {
    final sortedDays = data.wordsPerDay.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_edu_rounded, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                'Үгсийн түүх',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (sortedDays.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Түүх байхгүй байна.',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedDays.take(30).length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = sortedDays[index];
                final date = _parseDateKey(entry.key);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '${entry.value}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDisplayDate(date),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '${entry.value} үг шинээр',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.check_circle_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _getDayAbbreviation(int weekday) {
    const days = ['Д', 'М', 'М', 'П', 'Б', 'Бя', 'Ня'];
    return days[weekday - 1];
  }

  String _formatDisplayDate(DateTime date) {
    const months = ['', '1 сар', '2 сар', '3 сар', '4 сар', '5 сар', '6 сар', 
                    '7 сар', '8 сар', '9 сар', '10 сар', '11 сар', '12 сар'];
    return '${months[date.month]} ${date.day}';
  }
}

class StreakData {
  final int currentStreak;
  final int longestStreak;
  final List<DayActivity> last7Days;
  final int totalWords;
  final int totalReviews;
  final SplayTreeMap<String, int> wordsPerDay;

  StreakData({
    required this.currentStreak,
    required this.longestStreak,
    required this.last7Days,
    required this.totalWords,
    required this.totalReviews,
    required this.wordsPerDay,
  });
}

class DayActivity {
  final DateTime date;
  final int wordCount;
  final bool hasActivity;

  DayActivity({
    required this.date,
    required this.wordCount,
    required this.hasActivity,
  });
}
