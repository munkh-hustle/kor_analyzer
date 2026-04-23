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
  });
  
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
      };
  
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
}

/// Result of a review session
class ReviewResult {
  final Flashcard flashcard;
  final int quality; // 0-5 scale (Anki style)
  final DateTime reviewedAt;
  
  ReviewResult({
    required this.flashcard,
    required this.quality,
    required this.reviewedAt,
  });
}
