// lib/widgets/dictionary_popup.dart
import 'package:flutter/material.dart';
import 'dart:convert';

class DictionaryPopup extends StatelessWidget {
  final String word;
  final String tag;
  final String? definition;
  final String? multilanListJson;

  const DictionaryPopup({
    super.key,
    required this.word,
    required this.tag,
    this.definition,
    this.multilanListJson,
  });

  @override
  Widget build(BuildContext context) {
    // Parse multilanList if available
    List<dynamic>? multilanList;
    if (multilanListJson != null && multilanListJson!.isNotEmpty) {
      try {
        multilanList = json.decode(multilanListJson!);
      } catch (e) {
        print('Error parsing multilanList: $e');
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
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
            const SizedBox(height: 20),
            
            // Multi-language translations
            if (multilanList != null && multilanList.isNotEmpty) ...[
              const Text(
                '다국어 번역',
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
                  children: multilanList.map((item) {
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
                                nationCodeName,
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
            
            // Korean Definition
            const Text(
              '뜻',
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
                      '사전에 등록되지 않은 단어입니다.',
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
            
            // Usage example placeholder
            const Text(
              '사용 예',
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
                '이 단어는 문장에서 ${_getExample(word)}와 같이 사용됩니다.',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
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
      'NNG': '일반 명사',
      'NNP': '고유 명사',
      'NNB': '의존 명사',
      'VV': '동사',
      'VA': '형용사',
      'VX': '보조 용언',
      'JKS': '주격 조사',
      'JKO': '목적격 조사',
      'JKB': '부사격 조사',
    };
    return descriptions[tag] ?? tag;
  }

  String _getExample(String word) {
    return '"$word"';
  }
}
