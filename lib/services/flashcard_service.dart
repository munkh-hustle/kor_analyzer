// lib/services/flashcard_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/flashcard.dart';
import 'dart:io';

class FlashcardService {
  static final FlashcardService _instance = FlashcardService._internal();
  factory FlashcardService() => _instance;
  FlashcardService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'korean_reader_flashcards.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Create flashcards table with SRS fields
    await db.execute('''
      CREATE TABLE flashcards (
        id TEXT PRIMARY KEY,
        paragraphId TEXT NOT NULL,
        paragraph TEXT NOT NULL,
        word TEXT NOT NULL,
        tag TEXT NOT NULL,
        definition TEXT,
        createdAt INTEGER NOT NULL,
        interval INTEGER NOT NULL DEFAULT 0,
        easeFactor REAL NOT NULL DEFAULT 2.5,
        repetitions INTEGER NOT NULL DEFAULT 0,
        lastReviewedAt INTEGER NOT NULL,
        nextReviewAt INTEGER NOT NULL
      )
    ''');

    // Create indexes for efficient queries
    await db.execute('''
      CREATE INDEX idx_next_review ON flashcards(nextReviewAt ASC)
    ''');
    
    await db.execute('''
      CREATE INDEX idx_paragraph_id ON flashcards(paragraphId)
    ''');
  }

  /// Create a new flashcard from a history entry
  Future<void> createFlashcard({
    required String paragraphId,
    required String paragraph,
    required String word,
    required String tag,
    String? definition,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final id = '${now.millisecondsSinceEpoch}_${word.hashCode}';
    
    final flashcard = Flashcard(
      id: id,
      paragraphId: paragraphId,
      paragraph: paragraph,
      word: word,
      tag: tag,
      definition: definition,
      createdAt: now,
      lastReviewedAt: now,
      nextReviewAt: now, // Due immediately for new cards
    );

    await db.insert(
      'flashcards',
      flashcard.toJson(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Get all flashcards due for review (Anki-style queue)
  Future<List<Flashcard>> getDueFlashcards({int limit = 20}) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'flashcards',
      where: 'nextReviewAt <= ?',
      whereArgs: [now],
      orderBy: 'nextReviewAt ASC',
      limit: limit,
    );

    return List.generate(maps.length, (i) {
      return Flashcard.fromJson(maps[i]);
    });
  }

  /// Get all flashcards (for management)
  Future<List<Flashcard>> getAllFlashcards() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'flashcards',
      orderBy: 'nextReviewAt ASC',
    );

    return List.generate(maps.length, (i) {
      return Flashcard.fromJson(maps[i]);
    });
  }

  /// Get flashcards by paragraph ID
  Future<List<Flashcard>> getFlashcardsByParagraph(String paragraphId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'flashcards',
      where: 'paragraphId = ?',
      whereArgs: [paragraphId],
    );

    return List.generate(maps.length, (i) {
      return Flashcard.fromJson(maps[i]);
    });
  }

  /// Update flashcard after review using SM-2 algorithm
  Future<Flashcard> updateFlashcardAfterReview(
    String id,
    int quality, // 0-5 scale (Anki style)
  ) async {
    final db = await database;
    
    // Get current flashcard
    final currentCards = await db.query(
      'flashcards',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (currentCards.isEmpty) {
      throw Exception('Flashcard not found');
    }
    
    var flashcard = Flashcard.fromJson(currentCards.first);
    
    // SM-2 Algorithm Implementation
    double newEaseFactor = flashcard.easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (newEaseFactor < 1.3) newEaseFactor = 1.3;
    
    int newRepetitions = flashcard.repetitions;
    int newInterval = flashcard.interval;
    
    if (quality >= 3) {
      // Successful review
      newRepetitions = flashcard.repetitions + 1;
      
      if (newRepetitions == 1) {
        newInterval = 1;
      } else if (newRepetitions == 2) {
        newInterval = 6;
      } else {
        newInterval = (flashcard.interval * newEaseFactor).round();
      }
    } else {
      // Failed review - reset
      newRepetitions = 0;
      newInterval = 1;
    }
    
    final now = DateTime.now();
    final nextReviewAt = now.add(Duration(days: newInterval));
    
    // Update the flashcard
    final updatedFlashcard = Flashcard(
      id: flashcard.id,
      paragraphId: flashcard.paragraphId,
      paragraph: flashcard.paragraph,
      word: flashcard.word,
      tag: flashcard.tag,
      definition: flashcard.definition,
      createdAt: flashcard.createdAt,
      interval: newInterval,
      easeFactor: newEaseFactor,
      repetitions: newRepetitions,
      lastReviewedAt: now,
      nextReviewAt: nextReviewAt,
    );
    
    await db.update(
      'flashcards',
      updatedFlashcard.toJson(),
      where: 'id = ?',
      whereArgs: [id],
    );
    
    return updatedFlashcard;
  }

  /// Delete a flashcard
  Future<void> deleteFlashcard(String id) async {
    final db = await database;
    await db.delete(
      'flashcards',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete flashcards by paragraph ID (when history is deleted)
  Future<void> deleteFlashcardsByParagraph(String paragraphId) async {
    final db = await database;
    await db.delete(
      'flashcards',
      where: 'paragraphId = ?',
      whereArgs: [paragraphId],
    );
  }

  /// Clear all flashcards
  Future<void> clearAllFlashcards() async {
    final db = await database;
    await db.delete('flashcards');
  }

  /// Get count of due flashcards
  Future<int> getDueCount() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM flashcards WHERE nextReviewAt <= ?',
      [now],
    );
    
    return (result.first['cnt'] as num?)?.toInt() ?? 0;
  }

  /// Get total flashcard count
  Future<int> getTotalCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM flashcards');
    return (result.first['cnt'] as num?)?.toInt() ?? 0;
  }

  /// Check if flashcard exists for a word in a paragraph
  Future<bool> exists(String paragraphId, String word) async {
    final db = await database;
    final result = await db.query(
      'flashcards',
      where: 'paragraphId = ? AND word = ?',
      whereArgs: [paragraphId, word],
      limit: 1,
    );
    return result.isNotEmpty;
  }
}
