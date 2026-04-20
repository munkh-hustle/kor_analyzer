// lib/services/dictionary_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:io';

class DictionaryLoadingProgress {
  final int currentFile;
  final int totalFiles;
  final int totalEntriesLoaded;
  final String? currentFileName;

  DictionaryLoadingProgress({
    required this.currentFile,
    required this.totalFiles,
    required this.totalEntriesLoaded,
    this.currentFileName,
  });

  double get progress => totalFiles > 0 ? currentFile / totalFiles : 0.0;
}

class DictionaryService {
  Database? _database;
  bool _initialized = false;
  Function(DictionaryLoadingProgress)? onProgressUpdate;

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
    Database tempDb =
        await openDatabase(dbPath, version: 1, onCreate: _createDatabase);

    // Define the dictionary files to load (hardcoded list instead of reading AssetManifest)
    final allDictionaryFiles = [
      'assets/dictionary data/1_5000_20260319.json',
      'assets/dictionary data/2_5000_20260319.json',
      'assets/dictionary data/3_5000_20260319.json',
      'assets/dictionary data/4_5000_20260319.json',
      'assets/dictionary data/5_5000_20260319.json',
      'assets/dictionary data/6_5000_20260319.json',
      'assets/dictionary data/7_5000_20260319.json',
      'assets/dictionary data/8_5000_20260319.json',
      'assets/dictionary data/9_5000_20260319.json',
      'assets/dictionary data/10_5000_20260319.json',
      'assets/dictionary data/11_3439_20260319.json',
    ];

    // Filter to only include files that exist (check by trying to load)
    final dictionaryFiles = <String>[];
    for (var filePath in allDictionaryFiles) {
      try {
        // Try to load a small portion to verify file exists
        final byteData = await rootBundle.load(filePath);
        if (byteData.lengthInBytes > 0) {
          dictionaryFiles.add(filePath);
        }
      } catch (e) {
        // File doesn't exist or is inaccessible, skip it
        print('Skipping missing file: $filePath');
      }
    }

    print('Found ${dictionaryFiles.length} dictionary JSON files to load');

    int totalInserted = 0;
    int fileCount = 0;

    for (var filePath in dictionaryFiles) {
      fileCount++;
      try {
        final fileName = filePath.split('/').last;
        print('Loading file $fileCount/${dictionaryFiles.length}: $filePath');

        // Notify progress - starting file
        onProgressUpdate?.call(DictionaryLoadingProgress(
          currentFile: fileCount,
          totalFiles: dictionaryFiles.length,
          totalEntriesLoaded: totalInserted,
          currentFileName: fileName,
        ));

        // Load file as bytes first to handle large files better
        final byteData = await rootBundle.load(filePath);
        final jsonString = String.fromCharCodes(byteData.buffer.asUint8List());

        // Clear reference to allow garbage collection
        byteData.buffer.asUint8List();

        if (jsonString.isEmpty) {
          print('Warning: Empty file $filePath');
          continue;
        }

        // Try to detect JSON format and parse accordingly
        int fileInserted = 0;

        if (jsonString.contains('"LexicalResource"')) {
          // New format: LexicalResource -> Lexicon -> LexicalEntry
          fileInserted = await _parseLexicalResourceFormat(tempDb, jsonString, 
            (insertedInFile) {
              // Notify progress during parsing
              onProgressUpdate?.call(DictionaryLoadingProgress(
                currentFile: fileCount,
                totalFiles: dictionaryFiles.length,
                totalEntriesLoaded: totalInserted + insertedInFile,
                currentFileName: fileName,
              ));
            },
          );
        } else if (jsonString.contains('"channel"')) {
          // Old format: channel -> item
          fileInserted = await _parseChannelFormat(tempDb, jsonString);
        } else {
          print('Warning: Unknown JSON format in $filePath');
        }

        // Clear jsonString reference to allow garbage collection
        // ignore: unnecessary_statements
        jsonString;

        print(
            'Inserted $fileInserted entries from $filePath (File $fileCount/${dictionaryFiles.length})');
        totalInserted += fileInserted;

        // Force garbage collection hint by yielding and waiting
        await Future.delayed(Duration(milliseconds: 100));

        // Print progress
        print(
            'Progress: $fileCount/${dictionaryFiles.length} files, $totalInserted total entries');
      } catch (e) {
        print('Error loading dictionary file $filePath: $e');
        // Continue with next file even if one fails
      }
    }

    print('Total dictionary entries inserted: $totalInserted');
    
    // Notify completion
    onProgressUpdate?.call(DictionaryLoadingProgress(
      currentFile: dictionaryFiles.length,
      totalFiles: dictionaryFiles.length,
      totalEntriesLoaded: totalInserted,
      currentFileName: null,
    ));

    await tempDb.close();
  }

  Future<int> _parseLexicalResourceFormat(
      Database db, String jsonString, [Function(int)? onProgress]) async {
    int inserted = 0;

    // Parse the JSON manually due to its large size
    // We'll use a streaming approach to extract LexicalEntry objects
    final content = jsonString;

    // Find LexicalEntry array
    final lexEntryStart = content.indexOf('"LexicalEntry"');
    if (lexEntryStart == -1) return 0;

    final arrayStart = content.indexOf('[', lexEntryStart);
    if (arrayStart == -1) return 0;

    // Extract entries by finding {"Lemma": patterns
    int pos = arrayStart + 1;
    while (pos < content.length) {
      // Skip whitespace and commas
      while (pos < content.length &&
          (content[pos] == ' ' ||
              content[pos] == '\n' ||
              content[pos] == '\r' ||
              content[pos] == ',' ||
              content[pos] == '\t')) {
        pos++;
      }

      if (pos >= content.length || content[pos] == ']') break;

      // Check for Lemma entry - the JSON format is: {\n                "Lemma": {...
      // So we need to skip the opening brace and whitespace first
      int checkPos = pos;
      
      // Skip leading whitespace
      while (checkPos < content.length && 
             (content[checkPos] == ' ' || 
              content[checkPos] == '\n' || 
              content[checkPos] == '\r' || 
              content[checkPos] == '\t' ||
              content[checkPos] == ',')) {
        checkPos++;
      }
      
      // Check if it starts with {
      bool hasLemmaPattern = false;
      if (checkPos < content.length && content[checkPos] == '{') {
        checkPos++; // skip {
        
        // Skip more whitespace after {
        while (checkPos < content.length && 
               (content[checkPos] == ' ' || 
                content[checkPos] == '\n' || 
                content[checkPos] == '\r' || 
                content[checkPos] == '\t')) {
          checkPos++;
        }
        
        // Now check for "Lemma"
        if (checkPos < content.length && 
            content.substring(checkPos).startsWith('"Lemma"')) {
          hasLemmaPattern = true;
        }
      }
      
      if (hasLemmaPattern) {
        // Find the end of this entry
        int braceCount = 0;
        int entryStart = pos;
        int entryEnd = pos;

        for (int i = pos; i < content.length; i++) {
          if (content[i] == '{')
            braceCount++;
          else if (content[i] == '}') {
            braceCount--;
            if (braceCount == 0) {
              entryEnd = i + 1;
              break;
            }
          }
        }

        if (entryEnd > entryStart) {
          try {
            final entryStr = content.substring(entryStart, entryEnd);
            final entry = json.decode(entryStr);

            // Extract word from Lemma
            final lemma = entry['Lemma'];
            if (lemma != null && lemma is Map) {
              final feat = lemma['feat'];
              if (feat != null && feat is Map) {
                final word = feat['val']?.toString() ?? '';

                if (word.isNotEmpty) {
                  // Extract Sense information
                  String tag = '';
                  String definition = '';
                  String mongolianDefinition = '';
                  String englishDefinition = '';
                  String koreanDefinition = '';
                  List<String> examples = [];

                  final senses = entry['Sense'];
                  if (senses != null) {
                    // Handle both List and Map types for Sense
                    List senseList = [];
                    if (senses is List) {
                      senseList = senses;
                    } else if (senses is Map) {
                      senseList = [senses];
                    }

                    if (senseList.isNotEmpty) {
                      final sense = senseList[0];
                      if (sense is Map) {
                        // Get equivalents (translations/definitions in different languages)
                        final equivalents = sense['Equivalent'];
                        if (equivalents != null && equivalents is List) {
                          String firstDefinition = '';
                          String firstTag = '';

                          for (var eq in equivalents) {
                            if (eq is Map) {
                              final feats = eq['feat'];
                              if (feats != null && feats is List) {
                                String lang = '';
                                String defText = '';
                                String lemmaText = '';

                                for (var f in feats) {
                                  if (f is Map) {
                                    if (f['att'] == 'language') {
                                      lang = f['val']?.toString() ?? '';
                                    } else if (f['att'] == 'definition') {
                                      defText = f['val']?.toString() ?? '';
                                    } else if (f['att'] == 'lemma') {
                                      lemmaText = f['val']?.toString() ?? '';
                                    }
                                  }
                                }

                                // Store first available definition and tag as fallback
                                if (firstDefinition.isEmpty &&
                                    defText.isNotEmpty) {
                                  firstDefinition = '[$lang] $defText';
                                  firstTag = lemmaText;
                                }

                                // Extract Mongolian, English, and Korean definitions separately
                                if (lang == '몽골어' && defText.isNotEmpty) {
                                  mongolianDefinition = defText;
                                  if (lemmaText.isNotEmpty) {
                                    mongolianDefinition = '$lemmaText - $defText';
                                  }
                                } else if (lang == '영어' && defText.isNotEmpty) {
                                  englishDefinition = defText;
                                  if (lemmaText.isNotEmpty) {
                                    englishDefinition = '$lemmaText - $defText';
                                  }
                                } else if (lang == '한국어' && defText.isNotEmpty) {
                                  koreanDefinition = defText;
                                }

                                // Get tag from Korean entry if available
                                if (lang == '한국어' && lemmaText.isNotEmpty) {
                                  tag = lemmaText;
                                }
                              }
                            }
                          }

                          // Build combined definition with Mongolian, English, and Korean
                          List<String> defParts = [];
                          if (mongolianDefinition.isNotEmpty) {
                            defParts.add('🇲🇳 몽골어: $mongolianDefinition');
                          }
                          if (englishDefinition.isNotEmpty) {
                            defParts.add('🇬🇧 영어: $englishDefinition');
                          }
                          if (koreanDefinition.isNotEmpty) {
                            defParts.add('🇰🇷 한국어: $koreanDefinition');
                          }
                          
                          // If no specific language definitions found, use first available
                          if (defParts.isEmpty && firstDefinition.isNotEmpty) {
                            definition = firstDefinition;
                          } else {
                            definition = defParts.join('\n\n');
                          }
                          
                          if (tag.isEmpty && firstTag.isNotEmpty) {
                            tag = firstTag;
                          }
                        }

                        // Get examples from SenseExample
                        final senseExamples = sense['SenseExample'];
                        if (senseExamples != null) {
                          List exampleList = [];
                          if (senseExamples is List) {
                            exampleList = senseExamples;
                          } else if (senseExamples is Map) {
                            exampleList = [senseExamples];
                          }

                          for (var ex in exampleList) {
                            if (ex is Map) {
                              final feats = ex['feat'];
                              if (feats != null && feats is List) {
                                for (var f in feats) {
                                  if (f is Map && f['att'] == 'example') {
                                    final exampleText =
                                        f['val']?.toString() ?? '';
                                    if (exampleText.isNotEmpty) {
                                      examples.add(exampleText);
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }

                  // Insert into database
                  await db.insert(
                      'dictionary',
                      {
                        'word': word,
                        'tag': tag,
                        'definition': definition,
                        'examples': examples.join('\n'),
                      },
                      conflictAlgorithm: ConflictAlgorithm.ignore);
                  inserted++;
                  
                  // Notify progress every 100 entries to avoid too many callbacks
                  if (inserted % 100 == 0 && onProgress != null) {
                    onProgress(inserted);
                  }
                }
              }
            }
          } catch (e) {
            // Skip malformed entries
            print('Error parsing entry at pos $pos: $e');
          }

          pos = entryEnd;
        } else {
          pos++;
        }
      } else {
        // Not a Lemma entry, skip this character
        pos++;
      }
    }

    print('Finished parsing LexicalResource format. Total inserted: $inserted');
    
    // Final progress notification
    if (onProgress != null) {
      onProgress(inserted);
    }
    
    return inserted;
  }

  Future<int> _parseChannelFormat(Database db, String jsonString) async {
    int inserted = 0;
    Map<String, dynamic> jsonData = json.decode(jsonString);

    // Parse and insert dictionary items
    if (jsonData.containsKey('channel') &&
        jsonData['channel'].containsKey('item')) {
      List<dynamic> items = jsonData['channel']['item'];

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
              if (senseDataList != null &&
                  senseDataList is List &&
                  senseDataList.isNotEmpty) {
                var firstSense = senseDataList[0];

                // Get definition
                var definitionData = firstSense['definition'];
                if (definitionData != null &&
                    definitionData is List &&
                    definitionData.isNotEmpty) {
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
              await db.insert(
                  'dictionary',
                  {
                    'word': word,
                    'tag': tag,
                    'definition': definition,
                    'examples': examples,
                  },
                  conflictAlgorithm: ConflictAlgorithm.ignore);
              inserted++;
            }
          }
        } catch (e) {
          print('Error processing dictionary item: $e');
        }
      }
    }

    return inserted;
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
      {
        'word': '페이지',
        'tag': 'NNG',
        'definition': '책, 신문, 문서 등의 한 면. 또는 웹사이트의 화면.'
      },
      {
        'word': '통해',
        'tag': 'VV',
        'definition': '길이 뚫리어 나아가다. 또는 어떤 매체나 수단을 이용하다.'
      },
      {
        'word': '제보',
        'tag': 'NNG',
        'definition': '정보를 제공함. 특히 뉴스거리가 될 만한 정보를 알림.'
      },
      {
        'word': '주시면',
        'tag': 'VX',
        'definition': '주다의 높임말. 상대방에게 무엇을 건네거나 해줌을 공손하게 표현.'
      },
      {'word': '감사', 'tag': 'NNG', 'definition': '고맙게 여김. 또는 그런 마음.'},
      {
        'word': '하겠습니다',
        'tag': 'XSA',
        'definition': '하다의 높임 표현. 앞말이 뜻하는 행동을 하겠다는 의지 표현.'
      },
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
