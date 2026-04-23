// lib/models/search_history_entry.dart
import 'dart:convert';

class SearchHistoryEntry {
  final String id;
  final String word;
  final String tag;
  final DateTime timestamp;
  final String? definition;
  final String? multilanListJson;
  final String? fullSenseInfoJson;
  final String? gubun;
  final String? synonymsJson;
  final String? antonymsJson;
  final String? examplesJson;

  SearchHistoryEntry({
    required this.id,
    required this.word,
    required this.tag,
    required this.timestamp,
    this.definition,
    this.multilanListJson,
    this.fullSenseInfoJson,
    this.gubun,
    this.synonymsJson,
    this.antonymsJson,
    this.examplesJson,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'word': word,
        'tag': tag,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'definition': definition,
        'multilanListJson': multilanListJson,
        'fullSenseInfoJson': fullSenseInfoJson,
        'gubun': gubun,
        'synonymsJson': synonymsJson,
        'antonymsJson': antonymsJson,
        'examplesJson': examplesJson,
      };

  factory SearchHistoryEntry.fromJson(Map<String, dynamic> json) =>
      SearchHistoryEntry(
        id: json['id'],
        word: json['word'],
        tag: json['tag'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
        definition: json['definition'],
        multilanListJson: json['multilanListJson'],
        fullSenseInfoJson: json['fullSenseInfoJson'],
        gubun: json['gubun'],
        synonymsJson: json['synonymsJson'],
        antonymsJson: json['antonymsJson'],
        examplesJson: json['examplesJson'],
      );

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.month}/${timestamp.day}';
    }
  }
}
