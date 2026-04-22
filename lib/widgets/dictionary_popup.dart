// lib/widgets/dictionary_popup.dart
import 'package:flutter/material.dart';
import 'dart:convert';

class DictionaryPopup extends StatelessWidget {
  final String word;
  final String tag;
  final String? definition;
  final String? multilanListJson;
  final String? fullSenseInfoJson;
  final String? gubun;
  
  const DictionaryPopup({
    super.key,
    required this.word,
    required this.tag,
    this.definition,
    this.multilanListJson,
    this.fullSenseInfoJson,
    this.gubun,
  });

  @override
  Widget build(BuildContext context) {
    // Prevent keyboard from showing when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).unfocus();
    });
    
    // Parse multilanList if available
    List<dynamic>? multilanList;
    if (multilanListJson != null && multilanListJson!.isNotEmpty) {
      try {
        multilanList = json.decode(multilanListJson!);
      } catch (e) {
        print('Error parsing multilanList: $e');
      }
    }
    
    // Parse full sense info if available
    Map<String, dynamic>? senseInfo;
    List<dynamic>? examList2;
    List<dynamic>? examList3;
    if (fullSenseInfoJson != null && fullSenseInfoJson!.isNotEmpty) {
      try {
        senseInfo = json.decode(fullSenseInfoJson!);
        final senseDataList = senseInfo?['senseDataList'] as List?;
        if (senseDataList != null && senseDataList.isNotEmpty) {
          final firstSense = senseDataList[0] as Map?;
          final examList = firstSense?['examList'] as Map?;
          examList2 = examList?['examList2'] as List?;
          examList3 = examList?['examList3'] as List?;
        }
      } catch (e) {
        print('Error parsing fullSenseInfo: $e');
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    word,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _getTagDescription(tag),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (gubun != null && gubun!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      gubun!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            
            // Multi-language translations (English and Mongolian only)
            if (multilanList != null && multilanList.isNotEmpty) ...[
              const Text(
                'Translations',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: multilanList.where((item) {
                    final nationCodeName = item['nation_code_name'] ?? '';
                    return nationCodeName == '영어' || nationCodeName == '몽골어';
                  }).map((item) {
                    final translation = item['multi_translation'] ?? '';
                    final multiDef = item['multi_definition'] ?? '';
                    final nationCodeName = item['nation_code_name'] ?? '';
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _getLanguageFlag(nationCodeName),
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                nationCodeName == '영어' ? 'English' : 'Mongolian',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (translation.isNotEmpty)
                            Text(
                              translation,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (multiDef.isNotEmpty)
                            Text(
                              multiDef,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                height: 1.5,
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Definition in English/Mongolian
            const Text(
              'Definition',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: definition == null || definition!.isEmpty
                  ? Text(
                      'Word not found in dictionary.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    )
                  : Text(
                      definition!,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
            ),
            
            const SizedBox(height: 20),
            
            // Usage examples from examList
            if ((examList2 != null && examList2.isNotEmpty) || 
                (examList3 != null && examList3.isNotEmpty)) ...[
              const Text(
                'Examples',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sentence examples (examList2)
                    if (examList2 != null && examList2.isNotEmpty) ...[
                      ...examList2.map((exam) {
                        final example = exam['example']?.toString() ?? '';
                        if (example.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            example,
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          ),
                        );
                      }).toList(),
                    ],
                    // Dialogue examples (examList3)
                    if (examList3 != null && examList3.isNotEmpty) ...[
                      if (examList2 != null && examList2.isNotEmpty)
                        const SizedBox(height: 8),
                      ...examList3.map((exam) {
                        final example = exam['example']?.toString() ?? '';
                        if (example.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            example,
                            style: TextStyle(
                              fontSize: 14, 
                              height: 1.5,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[800],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
              // Fallback placeholder if no examples
              const Text(
                'Examples',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'This word is used as "$word" in sentences.',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
          ),
        ),
      ),
    );
  }

  String _getLanguageFlag(String nationCodeName) {
    switch (nationCodeName) {
      case '영어':
        return '🇬🇧';
      case '몽골어':
        return '🇲🇳';
      case '한국어':
        return '🇰🇷';
      case '일본어':
        return '🇯🇵';
      case '중국어':
        return '🇨🇳';
      default:
        return '🌐';
    }
  }

  String _getTagDescription(String tag) {
    final descriptions = {
      'NNG': 'General Noun',
      'NNP': 'Proper Noun',
      'NNB': 'Dependent Noun',
      'VV': 'Verb',
      'VA': 'Adjective',
      'VX': 'Auxiliary Verb',
      'JKS': 'Subject Particle',
      'JKO': 'Object Particle',
      'JKB': 'Adverbial Particle',
      'JX': 'Particle',
      'EC': 'Ending',
      'XSV': 'Affix',
    };
    return descriptions[tag] ?? tag;
  }
}
