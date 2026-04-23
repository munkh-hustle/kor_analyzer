// lib/services/search_history_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/search_history_entry.dart';
import 'dart:io';

class SearchHistoryService {
  static final SearchHistoryService _instance = SearchHistoryService._internal();
  factory SearchHistoryService() => _instance;
  SearchHistoryService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'korean_search_history.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE search_history (
        id TEXT PRIMARY KEY,
        word TEXT NOT NULL,
        tag TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        definition TEXT,
        multilanListJson TEXT,
        fullSenseInfoJson TEXT,
        gubun TEXT,
        synonymsJson TEXT,
        antonymsJson TEXT,
        examplesJson TEXT
      )
    ''');

    // Create index on timestamp for efficient ordering
    await db.execute('''
      CREATE INDEX idx_search_timestamp ON search_history(timestamp DESC)
    ''');

    // Create index on word for duplicate detection
    await db.execute('''
      CREATE INDEX idx_search_word ON search_history(word)
    ''');
  }

  /// Save a search entry - updates timestamp if word already exists
  Future<void> saveSearch(
    String word, 
    String tag, {
    String? definition,
    String? multilanListJson,
    String? fullSenseInfoJson,
    String? gubun,
    String? synonymsJson,
    String? antonymsJson,
    String? examplesJson,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final id = '${now.millisecondsSinceEpoch}_${word.hashCode}';

    // Check if this word was recently searched (within last entry)
    final existingEntry = await _getRecentSearch(word);
    
    if (existingEntry != null) {
      // Update the existing entry with new timestamp
      await db.update(
        'search_history',
        {
          'timestamp': now.millisecondsSinceEpoch,
          'tag': tag,
          'definition': definition,
          'multilanListJson': multilanListJson,
          'fullSenseInfoJson': fullSenseInfoJson,
          'gubun': gubun,
          'synonymsJson': synonymsJson,
          'antonymsJson': antonymsJson,
          'examplesJson': examplesJson,
        },
        where: 'id = ?',
        whereArgs: [existingEntry.id],
      );
    } else {
      // Insert new entry
      final entry = SearchHistoryEntry(
        id: id,
        word: word,
        tag: tag,
        timestamp: now,
        definition: definition,
        multilanListJson: multilanListJson,
        fullSenseInfoJson: fullSenseInfoJson,
        gubun: gubun,
        synonymsJson: synonymsJson,
        antonymsJson: antonymsJson,
        examplesJson: examplesJson,
      );

      await db.insert(
        'search_history',
        entry.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Clean up old entries - keep only last 50
    await _cleanupOldEntries();
  }

  /// Get the most recent search entry for a word
  Future<SearchHistoryEntry?> _getRecentSearch(String word) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'search_history',
      where: 'word = ?',
      whereArgs: [word],
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return SearchHistoryEntry(
        id: maps[0]['id'],
        word: maps[0]['word'],
        tag: maps[0]['tag'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(maps[0]['timestamp']),
        definition: maps[0]['definition'],
        multilanListJson: maps[0]['multilanListJson'],
        fullSenseInfoJson: maps[0]['fullSenseInfoJson'],
        gubun: maps[0]['gubun'],
        synonymsJson: maps[0]['synonymsJson'],
        antonymsJson: maps[0]['antonymsJson'],
        examplesJson: maps[0]['examplesJson'],
      );
    }
    return null;
  }

  /// Remove oldest entries to keep only the last 50
  Future<void> _cleanupOldEntries() async {
    final db = await database;
    
    // Get IDs of entries to delete (all except the newest 50)
    final result = await db.rawQuery('''
      SELECT id FROM search_history 
      ORDER BY timestamp DESC 
      LIMIT -1 OFFSET 50
    ''');

    if (result.isNotEmpty) {
      final idsToDelete = result.map((r) => r['id'] as String).toList();
      await db.delete(
        'search_history',
        where: 'id IN (${List.filled(idsToDelete.length, '?').join(',')})',
        whereArgs: idsToDelete,
      );
    }
  }

  /// Get all search history entries, sorted by timestamp (newest first)
  Future<List<SearchHistoryEntry>> getSearchHistory() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'search_history',
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) {
      return SearchHistoryEntry(
        id: maps[i]['id'],
        word: maps[i]['word'],
        tag: maps[i]['tag'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(maps[i]['timestamp']),
        definition: maps[i]['definition'],
        multilanListJson: maps[i]['multilanListJson'],
        fullSenseInfoJson: maps[i]['fullSenseInfoJson'],
        gubun: maps[i]['gubun'],
        synonymsJson: maps[i]['synonymsJson'],
        antonymsJson: maps[i]['antonymsJson'],
        examplesJson: maps[i]['examplesJson'],
      );
    });
  }

  /// Delete a specific search history entry
  Future<void> deleteSearchEntry(String id) async {
    final db = await database;
    await db.delete(
      'search_history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Clear all search history
  Future<void> clearAllSearchHistory() async {
    final db = await database;
    await db.delete('search_history');
  }

  /// Check if there's any search history
  Future<bool> hasSearchHistory() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM search_history');
    final count = (result.first['cnt'] as num?)?.toInt() ?? 0;
    return count > 0;
  }
}
