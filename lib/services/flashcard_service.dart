// lib/services/flashcard_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/flashcard.dart';
import 'fsrs_scheduler.dart';
import 'dart:io';

class FlashcardService {
  static final FlashcardService _instance = FlashcardService._internal();
  factory FlashcardService() => _instance;
  FlashcardService._internal();

  Database? _database;
  FSRSScheduler? _scheduler;

  /// Get the FSRS scheduler instance
  FSRSScheduler get scheduler {
    _scheduler ??= FSRSScheduler();
    return _scheduler!;
  }

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
      version: 2, // Incremented for FSRS migration
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Create flashcards table with FSRS fields
    await db.execute('''
      CREATE TABLE flashcards (
        id TEXT PRIMARY KEY,
        paragraphId TEXT NOT NULL,
        paragraph TEXT NOT NULL,
        word TEXT NOT NULL,
        tag TEXT NOT NULL,
        definition TEXT,
        createdAt INTEGER NOT NULL,
        stability REAL NOT NULL DEFAULT 0.0,
        difficulty REAL NOT NULL DEFAULT 0.5,
        interval INTEGER NOT NULL DEFAULT 0,
        repetitions INTEGER NOT NULL DEFAULT 0,
        lastReviewedAt INTEGER NOT NULL,
        nextReviewAt INTEGER NOT NULL,
        retrievability REAL NOT NULL DEFAULT 1.0
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

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migrate from SM-2 to FSRS schema
      try {
        await db.execute('ALTER TABLE flashcards ADD COLUMN stability REAL DEFAULT 0.0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE flashcards ADD COLUMN difficulty REAL DEFAULT 0.5');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE flashcards ADD COLUMN retrievability REAL DEFAULT 1.0');
      } catch (_) {}
      
      // Convert easeFactor to initial stability/difficulty values
      // This is a simplified conversion - actual values would need more sophisticated mapping
      await db.execute('''
        UPDATE flashcards 
        SET stability = CASE 
          WHEN interval > 0 THEN interval * 0.5 
          ELSE 0.5 
        END,
        difficulty = 0.5
      WHERE stability IS NULL OR stability = 0
      ''');
    }
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

  /// Update flashcard after review using FSRS algorithm
  Future<Flashcard> updateFlashcardAfterReview(
    String id,
    int quality, // 0-3 scale (FSRS style: 0=Again, 1=Hard, 2=Good, 3=Easy)
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
    
    // Initialize scheduler if needed
    final sched = scheduler;
    
    // Convert SM-2 quality (0-5) to FSRS grade (0-3)
    int fsrsGrade;
    if (quality <= 1) {
      fsrsGrade = 0; // Again
    } else if (quality == 2) {
      fsrsGrade = 1; // Hard
    } else if (quality == 3) {
      fsrsGrade = 2; // Good
    } else {
      fsrsGrade = 3; // Easy
    }
    
    // Calculate elapsed days since last review
    final now = DateTime.now();
    final elapsedDays = now.difference(flashcard.lastReviewedAt).inDays.toDouble();
    
    // Use FSRS to calculate new interval and state
    Map<String, double> result;
    
    if (flashcard.repetitions == 0 && flashcard.stability == 0.0) {
      // New card - initialize with FSRS
      Map<String, double> initialState = sched.initializeCard();
      result = sched.calculateNextInterval(
        currentStability: initialState['stability']!,
        currentDifficulty: initialState['difficulty']!,
        grade: fsrsGrade,
        currentInterval: 0,
        elapsedDays: 0,
      );
    } else {
      // Existing card - use current FSRS state
      result = sched.calculateNextInterval(
        currentStability: flashcard.stability,
        currentDifficulty: flashcard.difficulty,
        grade: fsrsGrade,
        currentInterval: flashcard.interval,
        elapsedDays: elapsedDays,
      );
    }
    
    int newInterval = result['interval']!.round();
    double newStability = result['newStability']!;
    double newDifficulty = result['newDifficulty']!;
    double newRetrievability = result['retrievability']!;
    
    // Update repetitions based on success/failure
    int newRepetitions = flashcard.repetitions;
    if (fsrsGrade >= 2) {
      newRepetitions = flashcard.repetitions + 1;
    } else if (fsrsGrade == 0) {
      newRepetitions = 0; // Reset on failure
    }
    
    final nextReviewAt = now.add(Duration(days: newInterval));
    
    // Record review for ML optimization
    sched.recordReview(
      previousStability: flashcard.stability,
      previousDifficulty: flashcard.difficulty,
      grade: fsrsGrade,
      interval: flashcard.interval,
      recalled: fsrsGrade >= 2,
    );
    
    // Update the flashcard
    final updatedFlashcard = Flashcard(
      id: flashcard.id,
      paragraphId: flashcard.paragraphId,
      paragraph: flashcard.paragraph,
      word: flashcard.word,
      tag: flashcard.tag,
      definition: flashcard.definition,
      createdAt: flashcard.createdAt,
      stability: newStability,
      difficulty: newDifficulty,
      interval: newInterval,
      repetitions: newRepetitions,
      lastReviewedAt: now,
      nextReviewAt: nextReviewAt,
      retrievability: newRetrievability,
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

  /// Configure the desired retention rate (default 90%)
  /// Valid range: 0.75 - 0.95 (75% - 95%)
  void setDesiredRetention(double retention) {
    scheduler.setDesiredRetention(retention);
  }

  /// Get the current desired retention rate
  double getDesiredRetention() {
    return scheduler.getDesiredRetention;
  }

  /// Get FSRS scheduler statistics
  Map<String, dynamic> getSchedulerStats() {
    return scheduler.getStats();
  }

  /// Export FSRS state for backup
  Map<String, dynamic> exportSchedulerState() {
    return scheduler.exportState();
  }

  /// Import FSRS state from backup
  void importSchedulerState(Map<String, dynamic> state) {
    scheduler.importState(state);
  }

  /// Reset the ML optimization history
  void resetSchedulerHistory() {
    scheduler.resetHistory();
  }
}
