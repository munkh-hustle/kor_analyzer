// lib/widgets/dictionary_popup.dart
import 'package:flutter/material.dart';

class DictionaryPopup extends StatelessWidget {
  final String word;
  final String tag;
  final String? definition;

  const DictionaryPopup({
    super.key,
    required this.word,
    required this.tag,
    this.definition,
  });

  @override
  Widget build(BuildContext context) {
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
            
            // Definition
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
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildDefinitionParts(definition!).map((part) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: part,
                        );
                      }).toList(),
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

  List<Widget> _buildDefinitionParts(String definition) {
    List<Widget> parts = [];
    
    // Split by double newline to separate language sections
    final lines = definition.split('\n\n');
    
    for (var line in lines) {
      if (line.startsWith('🇲🇳')) {
        parts.add(_buildLanguageSection('몽골어', line.substring(3).replaceFirst('몽골어: ', ''), Colors.green));
      } else if (line.startsWith('🇬🇧')) {
        parts.add(_buildLanguageSection('영어', line.substring(3).replaceFirst('영어: ', ''), Colors.blue));
      } else if (line.startsWith('🇰🇷')) {
        parts.add(_buildLanguageSection('한국어', line.substring(3).replaceFirst('한국어: ', ''), Colors.red));
      } else {
        // Fallback for other formats
        parts.add(Text(
          line,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ));
      }
    }
    
    return parts;
  }

  Widget _buildLanguageSection(String language, String text, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          language,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
      ],
    );
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
    return '“$word”';
  }
}