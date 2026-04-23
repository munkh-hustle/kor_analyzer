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
  
  // SRS Fields (Anki-style SM-2 algorithm)
  final int interval; // Days until next review
  final double easeFactor; // Ease factor (starts at 2.5)
  final int repetitions; // Number of successful reviews
  final DateTime lastReviewedAt;
  final DateTime nextReviewAt;
  
  Flashcard({
    required this.id,
    required this.paragraphId,
    required this.paragraph,
    required this.word,
    required this.tag,
    this.definition,
    required this.createdAt,
    this.interval = 0,
    this.easeFactor = 2.5,
    this.repetitions = 0,
    required this.lastReviewedAt,
    required this.nextReviewAt,
  });
  
  Map<String, dynamic> toJson() => {
        'id': id,
        'paragraphId': paragraphId,
        'paragraph': paragraph,
        'word': word,
        'tag': tag,
        'definition': definition,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'interval': interval,
        'easeFactor': easeFactor,
        'repetitions': repetitions,
        'lastReviewedAt': lastReviewedAt.millisecondsSinceEpoch,
        'nextReviewAt': nextReviewAt.millisecondsSinceEpoch,
      };
  
  factory Flashcard.fromJson(Map<String, dynamic> json) => Flashcard(
        id: json['id'],
        paragraphId: json['paragraphId'],
        paragraph: json['paragraph'],
        word: json['word'],
        tag: json['tag'],
        definition: json['definition'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
        interval: json['interval'] ?? 0,
        easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
        repetitions: json['repetitions'] ?? 0,
        lastReviewedAt: DateTime.fromMillisecondsSinceEpoch(json['lastReviewedAt']),
        nextReviewAt: DateTime.fromMillisecondsSinceEpoch(json['nextReviewAt']),
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
