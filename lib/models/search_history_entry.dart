// lib/models/search_history_entry.dart
import 'dart:convert';

class SearchHistoryEntry {
  final String id;
  final String word;
  final String tag;
  final DateTime timestamp;
  final String? definition;

  SearchHistoryEntry({
    required this.id,
    required this.word,
    required this.tag,
    required this.timestamp,
    this.definition,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'word': word,
        'tag': tag,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'definition': definition,
      };

  factory SearchHistoryEntry.fromJson(Map<String, dynamic> json) =>
      SearchHistoryEntry(
        id: json['id'],
        word: json['word'],
        tag: json['tag'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
        definition: json['definition'],
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
}
