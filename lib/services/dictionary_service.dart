// lib/services/dictionary_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
      print('=== Creating new database ===');
      await _loadDictionaryFromJson(path);
    } else {
      print('=== Database already exists at: $path ===');
      // Check database version - increment version to force rebuild if needed
      // Temp DB version check: delete and recreate for testing
      // Uncomment below to force rebuild:
      await deleteDatabase(path);
      print('=== Deleted old database, will create new one ===');
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
      'assets/dictionary data/word_level01_01.json',
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
        print('Loading file $fileCount/${dictionaryFiles.length}: $filePath');

        // Load file as bytes first to handle large files better
        final byteData = await rootBundle.load(filePath);
        // Decode UTF-8 properly by using the raw bytes directly with utf8.decoder
        final jsonString = utf8.decode(byteData.buffer.asUint8List());

        if (jsonString.isEmpty) {
          print('Warning: Empty file $filePath');
          continue;
        }

        // Try to detect JSON format and parse accordingly
        int fileInserted = 0;

        if (jsonString.contains('"LexicalResource"')) {
          // New format: LexicalResource -> Lexicon -> LexicalEntry
          fileInserted = await _parseLexicalResourceFormat(tempDb, jsonString);
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
    
    // Verify that 마음 was inserted by querying the temp database
    print('=== Verifying 마음 in database ===');
    final verifyResult = await tempDb.rawQuery(
        'SELECT word, tag FROM dictionary WHERE word = ?', ['마음']);
    if (verifyResult.isEmpty) {
      print('=== WARNING: 마음 NOT found in database after insertion! ===');
      // Try LIKE query to find similar entries
      final likeVerify = await tempDb.rawQuery(
          'SELECT word, tag, LENGTH(word) as len FROM dictionary WHERE word LIKE ? LIMIT 10',
          ['%마음%']);
      if (likeVerify.isNotEmpty) {
        print('=== Found ${likeVerify.length} similar entries with LIKE: ===');
        for (var r in likeVerify) {
          final dbWord = r['word'].toString();
          print('===   Similar: word="${r['word']}" (len=${r['len']}, bytes=${dbWord.codeUnits}), tag="${r['tag']}" ===');
        }
      } else {
        print('=== No entries containing "마음" found at all ===');
      }
    } else {
      print('=== SUCCESS: 마음 found in database with ${verifyResult.length} entries ===');
      for (var r in verifyResult) {
        print('===   DB entry: word="${r['word']}", tag="${r['tag']}" ===');
      }
    }
    
    _initialized = true;

    await tempDb.close();
  }

  Future<int> _parseLexicalResourceFormat(
      Database db, String jsonString) async {
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

      // Skip leading whitespace, commas, and opening braces
      while (checkPos < content.length &&
          (content[checkPos] == ' ' ||
              content[checkPos] == '\n' ||
              content[checkPos] == '\r' ||
              content[checkPos] == '\t' ||
              content[checkPos] == ',' ||
              content[checkPos] == '{')) {
        checkPos++;
      }

      // Now check for "Lemma"
      bool hasLemmaPattern = false;
      if (checkPos < content.length &&
          content.substring(checkPos).startsWith('"Lemma"')) {
        hasLemmaPattern = true;
      }

      if (hasLemmaPattern) {
        // Find the end of this entry by counting braces starting from "Lemma"
        int braceCount = 0;
        int entryStart = checkPos; // Start from "Lemma" position
        int entryEnd = checkPos;

        // First, find the opening brace before "Lemma"
        int searchPos = checkPos;
        while (searchPos > 0 && content[searchPos] != '{') {
          searchPos--;
        }
        entryStart = searchPos;

        // Now count braces from the opening brace
        for (int i = entryStart; i < content.length; i++) {
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
                                    mongolianDefinition =
                                        '$lemmaText - $defText';
                                  }
                                } else if (lang == '영어' && defText.isNotEmpty) {
                                  englishDefinition = defText;
                                  if (lemmaText.isNotEmpty) {
                                    englishDefinition = '$lemmaText - $defText';
                                  }
                                } else if (lang == '한국어' &&
                                    defText.isNotEmpty) {
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
                  if (inserted < 10 || word == '괴물') {
                    final defPreview = definition.length > 50 ? definition.substring(0, 50) : definition;
                    print(
                        'Inserting: word=$word, tag=$tag, def=$defPreview...');
                  }
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
                }
              }
            }
          } catch (e) {
            // Skip malformed entries
            print('Error parsing entry at pos $pos: $e');
          }

          pos = entryEnd;
        } else {
          // Couldn't find matching braces, skip forward
          pos = checkPos + 1;
        }
      } else {
        // Not a Lemma entry, skip this character
        pos++;
      }
    }

    print('Finished parsing LexicalResource format. Total inserted: $inserted');
    return inserted;
  }

  Future<int> _parseChannelFormat(Database db, String jsonString) async {
    int inserted = 0;
    print('=== Starting _parseChannelFormat ===');
    Map<String, dynamic> jsonData = json.decode(jsonString);
    print('=== JSON decoded successfully ===');

    // Parse and insert dictionary items
    if (jsonData.containsKey('channel') &&
        jsonData['channel'].containsKey('item')) {
      List<dynamic> items = jsonData['channel']['item'];
      print('=== Found ${items.length} items in JSON ===');

      for (var item in items) {
        try {
          var wordInfo = item['wordInfo'];
          var senseInfo = item['senseInfo'];

          if (wordInfo != null) {
            String word = wordInfo['org_word'] ?? '';
            String tag = wordInfo['sp_code_name'] ?? '';

            // Trim whitespace from word and tag to ensure clean data
            word = word.trim();
            tag = tag.trim();

            // Debug: Log first few entries and specifically '마음'
            if (inserted < 10 || word == '마음') {
              print(
                  '=== Parsed entry: word="$word" (len=${word.length}, bytes=${word.codeUnits}), tag="$tag" ===');
            }
            if (word == '마음') {
              print('=== FOUND 마음! Inserting into DB ===');
            }

            // Extract definition from senseInfo
            String definition = '';
            String examples = '';
            String multilanListJson = '';

            if (senseInfo != null) {
              var senseDataList = senseInfo['senseDataList'];
              if (senseDataList != null &&
                  senseDataList is List &&
                  senseDataList.isNotEmpty) {
                var firstSense = senseDataList[0];

                // Get definition - handle both string and list formats
                var definitionData = firstSense['definition'];
                if (definitionData != null) {
                  if (definitionData is String) {
                    definition = definitionData;
                  } else if (definitionData is List &&
                      definitionData.isNotEmpty) {
                    definition = definitionData[0]['content'] ?? '';
                  }
                }

                // Get multilanList for multi-language translations
                var multilanList = firstSense['multilanList'];
                if (multilanList != null && multilanList is List) {
                  try {
                    multilanListJson = json.encode(multilanList);
                  } catch (e) {
                    print('Error encoding multilanList: $e');
                  }
                }

                // Get examples from examList
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
              if (word == '마음') {
                final defPreview = definition.length > 50 ? definition.substring(0, 50) : definition;
                print('=== INSERTING 마음: word="$word", tag="$tag", def="$defPreview...", multilan=${multilanListJson.isNotEmpty ? "yes" : "no"} ===');
              }
              await db.insert(
                  'dictionary',
                  {
                    'word': word,
                    'tag': tag,
                    'definition': definition,
                    'examples': examples,
                    'multilan_list': multilanListJson,
                  },
                  conflictAlgorithm: ConflictAlgorithm.ignore);
              inserted++;
              if (word == '마음') {
                print('=== 마음 inserted successfully! Total inserted: $inserted ===');
              }
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
        examples TEXT,
        multilan_list TEXT
      )
    ''');
  }

  Future<Map<String, dynamic>?> getDefinitionWithMultiLang(String word, String tag) async {
    try {
      print('=== DictionaryService: Looking up word=$word, tag=$tag ===');
      final db = await database;
      print('=== Database opened successfully ===');

      // Trim whitespace from search parameters
      final searchWord = word.trim();
      
      // Convert Kiwi tag to Korean dictionary tag if needed
      String? koreanTag = _convertKiwiTagToKorean(tag);
      print('=== Converted tag: $tag -> $koreanTag ===');

      // First, check total count in database
      final countResult = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM dictionary'));
      print('=== Total entries in database: $countResult ===');

      // Check if word exists at all (with detailed logging)
      final wordCheck = await db.rawQuery(
          'SELECT word, tag, definition, multilan_list FROM dictionary WHERE word = ? LIMIT 5',
          [searchWord]);
      print('=== Words matching "$searchWord": ${wordCheck.length} ===');
      for (var w in wordCheck) {
        final defStr = w['definition']?.toString() ?? 'null';
        final defPreview = defStr.length > 50 ? defStr.substring(0, 50) : defStr;
        print(
            '===   Found: ${w['word']} (tag="${w['tag']}", def="$defPreview...") ===');
      }
      
      // Debug: Check for encoding/whitespace issues
      if (wordCheck.isEmpty) {
        print('=== Debug: Checking for similar words ===');
        // Log search word details
        print('=== Search word: "$searchWord" (len=${searchWord.length}) ===');
        print('=== Search word bytes: ${searchWord.codeUnits} ===');
        
        // Get sample of all words from DB to compare
        final allWords = await db.rawQuery(
            'SELECT word, LENGTH(word) as len FROM dictionary LIMIT 20');
        print('=== First 20 words in DB: ===');
        for (var w in allWords) {
          final dbWord = w['word'].toString();
          print('===   DB word: "$dbWord" (len=${w['len']}, bytes=${dbWord.codeUnits}) ===');
        }
        
        // Try a LIKE query to find similar words
        final likeResults = await db.rawQuery(
            'SELECT word, tag FROM dictionary WHERE word LIKE ? LIMIT 10',
            ['%$searchWord%']);
        print('=== LIKE query results for "%$searchWord%": ${likeResults.length} ===');
        for (var w in likeResults) {
          print('===   LIKE match: "${w['word']}" (tag="${w['tag']}") ===');
        }
      }

      // First try: exact tag match or empty tag or null tag
      List<Map<String, dynamic>> results = [];
      if (koreanTag != null && koreanTag.isNotEmpty) {
        results = await db.query(
          'dictionary',
          where: 'word = ? AND (tag = ? OR tag = ? OR tag IS NULL)',
          whereArgs: [searchWord, koreanTag, ''],
          limit: 1,
        );
      } else {
        // If no tag conversion, try with original tag
        results = await db.query(
          'dictionary',
          where: 'word = ? AND (tag = ? OR tag = ? OR tag IS NULL)',
          whereArgs: [searchWord, tag, ''],
          limit: 1,
        );
      }

      if (results.isNotEmpty) {
        print('=== Found definition with matching tag ===');
        return {
          'definition': results.first['definition'] as String?,
          'multilanList': results.first['multilan_list'] as String?,
        };
      }

      // Try without tag if not found
      final List<Map<String, dynamic>> fallbackResults = await db.query(
        'dictionary',
        where: 'word = ?',
        whereArgs: [searchWord],
        limit: 1,
      );

      if (fallbackResults.isNotEmpty) {
        print('=== Found definition with fallback (no tag match) ===');
        return {
          'definition': fallbackResults.first['definition'] as String?,
          'multilanList': fallbackResults.first['multilan_list'] as String?,
        };
      }

      print('=== No definition found for $word ===');
      
      // Additional debug: Show all entries with similar byte patterns
      print('=== Additional Debug Info ===');
      print('=== Looking for any entries that might match... ===');
      
      // Get a broader sample from the database
      final sampleResults = await db.rawQuery(
          'SELECT word, tag, LENGTH(word) as len FROM dictionary ORDER BY id LIMIT 50');
      print('=== Sample of 50 entries from DB: ===');
      bool foundSimilar = false;
      for (var r in sampleResults) {
        final dbWord = r['word'].toString();
        if (dbWord.contains('마') || dbWord.contains('음')) {
          print('===   SIMILAR: "${r['word']}" (tag="${r['tag']}", len=${r['len']}, bytes=${dbWord.codeUnits}) ===');
          foundSimilar = true;
        }
      }
      if (!foundSimilar) {
        print('=== No entries containing 마 or 음 found in first 50 entries ===');
      }
      
      return null;
    } catch (e) {
      print('=== Error in getDefinitionWithMultiLang: $e ===');
      return null;
    }
  }

  Future<String?> getDefinition(String word, String tag) async {
    final result = await getDefinitionWithMultiLang(word, tag);
    return result?['definition'] as String?;
  }

  /// Convert Kiwi morpheme tags to Korean dictionary tags
  String? _convertKiwiTagToKorean(String kiwiTag) {
    const tagMap = {
      'NNG': '명사', // General noun
      'NNP': '명사', // Proper noun
      'NNB': '의존 명사', // Dependent noun
      'NP': '대명사', // Pronoun
      'NR': '수사', // Numeral
      'VV': '동사', // Verb
      'VA': '형용사', // Adjective
      'VX': '보조 형용사', // Auxiliary verb (treated as adjective)
      'VCP': '품사 없음', // Positive copula
      'VCN': '품사 없음', // Negative copula
      'MM': '관형사', // Determiner
      'MAG': '부사', // Adverb (general)
      'MAJ': '부사', // Adverb (conjunctive)
      'IC': '감탄사', // Interjection
      'JKS': '조사', // Subject particle
      'JKC': '조사', // Predicative particle
      'JKG': '조사', // Attributive particle
      'JKO': '조사', // Object particle
      'JKB': '조사', // Adverbial particle
      'JKV': '조사', // Vocative particle
      'JKQ': '조사', // Quotative particle
      'JX': '조사', // Postposition
      'JC': '조사', // Conjunctive particle
      'EP': '품사 없음', // Pre-final ending
      'EF': '품사 없음', // Final ending
      'EC': '품사 없음', // Connective ending
      'ETN': '품사 없음', // Nominalizing ending
      'ETM': '품사 없음', // Adnominal ending
      'XPN': '접사', // Prefix
      'XSN': '접사', // Noun suffix
      'XSV': '접사', // Verb suffix
      'XSA': '접사', // Adjective suffix
      'XR': '어근', // Root
      'SF': '품사 없음', // Terminal punctuation
      'SP': '품사 없음', // Separator
      'SS': '품사 없음', // Quote mark
      'SL': '품사 없음', // Alphabet
      'SH': '품사 없음', // Hanja
      'SN': '품사 없음', // Number
    };
    return tagMap[kiwiTag];
  }
}
