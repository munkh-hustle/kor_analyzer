// lib/models/reading_history.dart
import 'dart:convert';

class ReadingHistoryEntry {
  final String id;
  final String text;
  final DateTime timestamp;
  final int wordCount;

  ReadingHistoryEntry({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.wordCount,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'wordCount': wordCount,
      };

  factory ReadingHistoryEntry.fromJson(Map<String, dynamic> json) =>
      ReadingHistoryEntry(
        id: json['id'],
        text: json['text'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
        wordCount: json['wordCount'],
      );

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${timestamp.month}/${timestamp.day}';
    }
  }

  String get preview {
    if (text.length <= 50) return text;
    return '${text.substring(0, 50)}...';
  }
}
