// lib/services/history_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/reading_history.dart';
import 'dart:io';

class HistoryService {
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'korean_reader_history.db');

    // Delete old database if exists (for clean migration)
    if (await databaseExists(path)) {
      await deleteDatabase(path);
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE reading_history (
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        wordCount INTEGER NOT NULL
      )
    ''');

    // Create index on timestamp for efficient ordering
    await db.execute('''
      CREATE INDEX idx_timestamp ON reading_history(timestamp DESC)
    ''');
  }

  /// Save a new reading history entry
  /// Automatically removes oldest entries if we exceed 50
  Future<void> saveHistory(String text) async {
    final db = await database;
    final now = DateTime.now();
    final id = '${now.millisecondsSinceEpoch}';
    
    // Count words (simple whitespace-based counting)
    final wordCount = text.trim().isEmpty 
        ? 0 
        : text.trim().split(RegExp(r'\s+')).length;

    final entry = ReadingHistoryEntry(
      id: id,
      text: text,
      timestamp: now,
      wordCount: wordCount,
    );

    await db.insert(
      'reading_history',
      entry.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Clean up old entries - keep only last 50
    await _cleanupOldEntries();
  }

  /// Remove oldest entries to keep only the last 50
  Future<void> _cleanupOldEntries() async {
    final db = await database;
    
    // Get IDs of entries to delete (all except the newest 50)
    final result = await db.rawQuery('''
      SELECT id FROM reading_history 
      ORDER BY timestamp DESC 
      LIMIT -1 OFFSET 50
    ''');

    if (result.isNotEmpty) {
      final idsToDelete = result.map((r) => r['id'] as String).toList();
      await db.delete(
        'reading_history',
        where: 'id IN (${List.filled(idsToDelete.length, '?').join(',')})',
        whereArgs: idsToDelete,
      );
    }
  }

  /// Get all reading history entries, sorted by timestamp (newest first)
  Future<List<ReadingHistoryEntry>> getHistory() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reading_history',
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) {
      return ReadingHistoryEntry(
        id: maps[i]['id'],
        text: maps[i]['text'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(maps[i]['timestamp']),
        wordCount: maps[i]['wordCount'],
      );
    });
  }

  /// Get a specific history entry by ID
  Future<ReadingHistoryEntry?> getHistoryEntry(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reading_history',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return ReadingHistoryEntry(
        id: maps[0]['id'],
        text: maps[0]['text'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(maps[0]['timestamp']),
        wordCount: maps[0]['wordCount'],
      );
    }
    return null;
  }

  /// Delete a specific history entry
  Future<void> deleteHistoryEntry(String id) async {
    final db = await database;
    await db.delete(
      'reading_history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Clear all history
  Future<void> clearAllHistory() async {
    final db = await database;
    await db.delete('reading_history');
  }

  /// Check if there's any history
  Future<bool> hasHistory() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM reading_history');
    final count = Sqflite.firstIntValue(result[0]['count']) ?? 0;
    return count > 0;
  }
}
