// lib/services/dictionary_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:io';

class DictionaryService {
  Database? _database;
  bool _initialized = false;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'korean_dictionary.db');
    
    // Check if database exists, if not, copy from assets and initialize
    bool dbExists = await databaseExists(path);
    
    if (!dbExists) {
      // Load dictionary data from JSON asset
      await _loadDictionaryFromJson(path);
    }
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  Future<void> _loadDictionaryFromJson(String dbPath) async {
    // Ensure directory exists
    await Directory(dirname(dbPath)).create(recursive: true);
    
    // Create temporary database to insert data
    Database tempDb = await openDatabase(dbPath, version: 1, onCreate: _createDatabase);
    
    // Load all JSON files from assets/dictionary data/ directory
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    
    // Filter for dictionary JSON files
    final dictionaryFiles = manifestMap.keys.where((key) => 
      key.startsWith('assets/dictionary data/') && key.endsWith('.json')
    ).toList();
    
    print('Found ${dictionaryFiles.length} dictionary JSON files to load');
    
    int totalInserted = 0;
    
    for (var filePath in dictionaryFiles) {
      try {
        print('Loading: $filePath');
        String jsonString = await rootBundle.loadString(filePath);
        Map<String, dynamic> jsonData = json.decode(jsonString);
        
        // Parse and insert dictionary items
        if (jsonData.containsKey('channel') && jsonData['channel'].containsKey('item')) {
          List<dynamic> items = jsonData['channel']['item'];
          int fileInserted = 0;
          
          for (var item in items) {
            try {
              var wordInfo = item['wordInfo'];
              var senseInfo = item['senseInfo'];
              
              if (wordInfo != null) {
                String word = wordInfo['org_word'] ?? '';
                String tag = wordInfo['sp_code_name'] ?? '';
                
                // Extract definition from senseInfo
                String definition = '';
                String examples = '';
                
                if (senseInfo != null) {
                  var senseDataList = senseInfo['senseDataList'];
                  if (senseDataList != null && senseDataList is List && senseDataList.isNotEmpty) {
                    var firstSense = senseDataList[0];
                    
                    // Get definition
                    var definitionData = firstSense['definition'];
                    if (definitionData != null && definitionData is List && definitionData.isNotEmpty) {
                      definition = definitionData[0]['content'] ?? '';
                    }
                    
                    // Get examples
                    var examList = firstSense['examList'];
                    if (examList != null) {
                      List<String> exampleTexts = [];
                      var examList2 = examList['examList2'];
                      if (examList2 != null && examList2 is List) {
                        for (var exam in examList2) {
                          if (exam['example'] != null) {
                            exampleTexts.add(exam['example']);
                          }
                        }
                      }
                      examples = exampleTexts.join('\n');
                    }
                  }
                }
                
                // Insert into database if we have a word
                if (word.isNotEmpty) {
                  await tempDb.insert('dictionary', {
                    'word': word,
                    'tag': tag,
                    'definition': definition,
                    'examples': examples,
                  }, conflictAlgorithm: ConflictAlgorithm.ignore);
                  fileInserted++;
                }
              }
            } catch (e) {
              print('Error processing dictionary item in $filePath: $e');
            }
          }
          
          print('Inserted $fileInserted entries from $filePath');
          totalInserted += fileInserted;
        }
      } catch (e) {
        print('Error loading dictionary file $filePath: $e');
      }
    }
    
    print('Total dictionary entries inserted: $totalInserted');
    
    await tempDb.close();
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE dictionary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        tag TEXT,
        definition TEXT,
        examples TEXT
      )
    ''');
    
    // Note: Dictionary data is now loaded from JSON asset in _loadDictionaryFromJson
    // Sample data is only inserted if JSON loading fails or for testing
    if (!_initialized) {
      await _insertSampleData(db);
    }
  }

  Future<void> _insertSampleData(Database db) async {
    final sampleWords = [
      {'word': '페이지', 'tag': 'NNG', 'definition': '책, 신문, 문서 등의 한 면. 또는 웹사이트의 화면.'},
      {'word': '통해', 'tag': 'VV', 'definition': '길이 뚫리어 나아가다. 또는 어떤 매체나 수단을 이용하다.'},
      {'word': '제보', 'tag': 'NNG', 'definition': '정보를 제공함. 특히 뉴스거리가 될 만한 정보를 알림.'},
      {'word': '주시면', 'tag': 'VX', 'definition': '주다의 높임말. 상대방에게 무엇을 건네거나 해줌을 공손하게 표현.'},
      {'word': '감사', 'tag': 'NNG', 'definition': '고맙게 여김. 또는 그런 마음.'},
      {'word': '하겠습니다', 'tag': 'XSA', 'definition': '하다의 높임 표현. 앞말이 뜻하는 행동을 하겠다는 의지 표현.'},
      {'word': '공부', 'tag': 'NNG', 'definition': '학문이나 기술을 배우고 익히는 것.'},
      {'word': '하다', 'tag': 'VV', 'definition': '어떤 행동이나 동작을 수행하다.'},
      {'word': '좋다', 'tag': 'VA', 'definition': '마음에 들거나 훌륭하다.'},
    ];
    
    for (var word in sampleWords) {
      await db.insert('dictionary', word);
    }
  }

  Future<String?> getDefinition(String word, String tag) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'dictionary',
      where: 'word = ? AND (tag = ? OR tag IS NULL)',
      whereArgs: [word, tag],
      limit: 1,
    );
    
    if (results.isNotEmpty) {
      return results.first['definition'] as String;
    }
    
    // Try without tag if not found
    final List<Map<String, dynamic>> fallbackResults = await db.query(
      'dictionary',
      where: 'word = ?',
      whereArgs: [word],
      limit: 1,
    );
    
    if (fallbackResults.isNotEmpty) {
      return fallbackResults.first['definition'] as String;
    }
    
    return null;
  }

  Future<void> addDefinition(String word, String tag, String definition) async {
    final db = await database;
    await db.insert(
      'dictionary',
      {
        'word': word,
        'tag': tag,
        'definition': definition,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}