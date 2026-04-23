// lib/models/flashcard.dart
import 'dart:convert';

class Flashcard {
  final String id;
  final String paragraphId; // Reference to the history entry
  final String paragraph; // The full paragraph text
  final String word; // The specific word to learn
  final String tag; // Word type/tag
  final String? definition; // Definition from dictionary
  final DateTime createdAt;
  
  // FSRS Fields (replacing SM-2 algorithm)
  final double stability; // Memory stability in days
  final double difficulty; // Difficulty level (0-1, lower is easier)
  final int interval; // Days until next review
  final int repetitions; // Number of successful reviews
  final DateTime lastReviewedAt;
  final DateTime nextReviewAt;
  final double retrievability; // Current probability of recall
  
  // New fields for enhanced scheduling
  final double? lastResponseTime; // Response time in seconds for last review
  final double? easeFactor; // Legacy ease factor for compatibility
  final Map<String, dynamic>? timeOfDayPerformance; // Performance by time of day
  
  Flashcard({
    required this.id,
    required this.paragraphId,
    required this.paragraph,
    required this.word,
    required this.tag,
    this.definition,
    required this.createdAt,
    this.stability = 0.0,
    this.difficulty = 0.5,
    this.interval = 0,
    this.repetitions = 0,
    required this.lastReviewedAt,
    required this.nextReviewAt,
    this.retrievability = 1.0,
    this.lastResponseTime,
    this.easeFactor,
    this.timeOfDayPerformance,
  });
  
  Map<String, dynamic> toMap() => {
        'id': id,
        'paragraphId': paragraphId,
        'paragraph': paragraph,
        'word': word,
        'tag': tag,
        'definition': definition,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'stability': stability,
        'difficulty': difficulty,
        'interval': interval,
        'repetitions': repetitions,
        'lastReviewedAt': lastReviewedAt.millisecondsSinceEpoch,
        'nextReviewAt': nextReviewAt.millisecondsSinceEpoch,
        'retrievability': retrievability,
        'lastResponseTime': lastResponseTime,
        'easeFactor': easeFactor,
        'timeOfDayPerformance': timeOfDayPerformance != null 
            ? jsonEncode(timeOfDayPerformance) 
            : null,
      };
  
  Map<String, dynamic> toJson() => {
        'id': id,
        'paragraphId': paragraphId,
        'paragraph': paragraph,
        'word': word,
        'tag': tag,
        'definition': definition,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'stability': stability,
        'difficulty': difficulty,
        'interval': interval,
        'repetitions': repetitions,
        'lastReviewedAt': lastReviewedAt.millisecondsSinceEpoch,
        'nextReviewAt': nextReviewAt.millisecondsSinceEpoch,
        'retrievability': retrievability,
        'lastResponseTime': lastResponseTime,
        'easeFactor': easeFactor,
        'timeOfDayPerformance': timeOfDayPerformance,
      };
  
  factory Flashcard.fromMap(Map<String, dynamic> json) => Flashcard(
        id: json['id'],
        paragraphId: json['paragraphId'],
        paragraph: json['paragraph'],
        word: json['word'],
        tag: json['tag'],
        definition: json['definition'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
        stability: (json['stability'] as num?)?.toDouble() ?? 0.0,
        difficulty: (json['difficulty'] as num?)?.toDouble() ?? 0.5,
        interval: json['interval'] ?? 0,
        repetitions: json['repetitions'] ?? 0,
        lastReviewedAt: DateTime.fromMillisecondsSinceEpoch(json['lastReviewedAt']),
        nextReviewAt: DateTime.fromMillisecondsSinceEpoch(json['nextReviewAt']),
        retrievability: (json['retrievability'] as num?)?.toDouble() ?? 1.0,
        lastResponseTime: (json['lastResponseTime'] as num?)?.toDouble(),
        easeFactor: (json['easeFactor'] as num?)?.toDouble(),
        timeOfDayPerformance: json['timeOfDayPerformance'] != null 
            ? jsonDecode(json['timeOfDayPerformance']) as Map<String, dynamic>
            : null,
      );
  
  factory Flashcard.fromJson(Map<String, dynamic> json) => Flashcard(
        id: json['id'],
        paragraphId: json['paragraphId'],
        paragraph: json['paragraph'],
        word: json['word'],
        tag: json['tag'],
        definition: json['definition'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
        stability: (json['stability'] as num?)?.toDouble() ?? 0.0,
        difficulty: (json['difficulty'] as num?)?.toDouble() ?? 0.5,
        interval: json['interval'] ?? 0,
        repetitions: json['repetitions'] ?? 0,
        lastReviewedAt: DateTime.fromMillisecondsSinceEpoch(json['lastReviewedAt']),
        nextReviewAt: DateTime.fromMillisecondsSinceEpoch(json['nextReviewAt']),
        retrievability: (json['retrievability'] as num?)?.toDouble() ?? 1.0,
        lastResponseTime: (json['lastResponseTime'] as num?)?.toDouble(),
        easeFactor: (json['easeFactor'] as num?)?.toDouble(),
        timeOfDayPerformance: json['timeOfDayPerformance'] != null 
            ? Map<String, dynamic>.from(json['timeOfDayPerformance']) 
            : null,
      );
  
  /// Check if the card is due for review
  bool get isDue => DateTime.now().isAfter(nextReviewAt);
  
  /// Get the status of the card
  String get status {
    if (repetitions == 0) return 'New';
    if (!isDue) return 'Learning';
    return 'Review';
  }
  
  /// Calculate days until next review
  int get daysUntilReview {
    if (!isDue) return 0;
    return nextReviewAt.difference(DateTime.now()).inDays.abs();
  }
  
  /// Get formatted next review date string
  String get nextReviewDateString {
    final now = DateTime.now();
    final diff = nextReviewAt.difference(now);
    
    if (diff.inSeconds < 0) return 'Due now';
    if (diff.inMinutes < 1) return 'In ${diff.inSeconds}s';
    if (diff.inHours < 1) return 'In ${diff.inMinutes}m';
    if (diff.inDays < 1) return 'In ${diff.inHours}h';
    if (diff.inDays == 1) return 'Tomorrow';
    if (diff.inDays < 7) return 'In ${diff.inDays} days';
    
    // Format as date
    return '${nextReviewAt.month}/${nextReviewAt.day}/${nextReviewAt.year}';
  }
}

/// Result of a review session
class ReviewResult {
  final Flashcard flashcard;
  final int quality; // 0-5 scale (Anki style)
  final DateTime reviewedAt;
  final double responseTime; // Time taken to answer in seconds
  final int hourOfDay; // Hour when review was completed (0-23)
  
  ReviewResult({
    required this.flashcard,
    required this.quality,
    required this.reviewedAt,
    required this.responseTime,
    required this.hourOfDay,
  });
}

/// Time-of-day performance statistics
class TimeOfDayStats {
  final int hour; // 0-23
  final int totalReviews;
  final int correctReviews;
  final double averageResponseTime; // in seconds
  final double accuracy; // 0-1
  
  TimeOfDayStats({
    required this.hour,
    required this.totalReviews,
    required this.correctReviews,
    required this.averageResponseTime,
    required this.accuracy,
  });
  
  Map<String, dynamic> toJson() => {
        'hour': hour,
        'totalReviews': totalReviews,
        'correctReviews': correctReviews,
        'averageResponseTime': averageResponseTime,
        'accuracy': accuracy,
      };
  
  factory TimeOfDayStats.fromJson(Map<String, dynamic> json) => TimeOfDayStats(
        hour: json['hour'],
        totalReviews: json['totalReviews'],
        correctReviews: json['correctReviews'],
        averageResponseTime: (json['averageResponseTime'] as num).toDouble(),
        accuracy: (json['accuracy'] as num).toDouble(),
      );
}
