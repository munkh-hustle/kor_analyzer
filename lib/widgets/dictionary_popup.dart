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
  final String? synonymsJson;
  final String? antonymsJson;
  final String? examplesJson;

  const DictionaryPopup({
    super.key,
    required this.word,
    required this.tag,
    this.definition,
    this.multilanListJson,
    this.fullSenseInfoJson,
    this.gubun,
    this.synonymsJson,
    this.antonymsJson,
    this.examplesJson,
  });

  @override
  Widget build(BuildContext context) {
    // Prevent keyboard from showing when dialog opens - multiple approaches for Android
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
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

    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.2),
        child: FocusScope(
          autofocus: false,
          canRequestFocus: false,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450, maxHeight: 650),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.surface,
                  colorScheme.surfaceContainerHighest.withOpacity(0.3),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient background
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              word,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon:
                                  const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                              padding: const EdgeInsets.all(4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildTagChip(
                              context, _getTagDescription(tag), colorScheme),
                          if (gubun != null && gubun!.isNotEmpty)
                            _buildTagChip(context, gubun!, colorScheme,
                                isSecondary: true),
                        ],
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Multi-language translations
                        if (multilanList != null &&
                            multilanList.isNotEmpty) ...[
                          _buildSectionHeader(
                              context, '다국어 번역', Icons.language_rounded),
                          const SizedBox(height: 12),
                          ...multilanList.map((item) {
                            final translation = item['multi_translation'] ?? '';
                            final multiDef = item['multi_definition'] ?? '';
                            final nationCodeName =
                                item['nation_code_name'] ?? '';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest
                                      .withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: colorScheme.outline.withOpacity(0.1),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          _getLanguageFlag(nationCodeName),
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          nationCodeName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (translation.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        translation,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                    if (multiDef.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        multiDef,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: colorScheme.onSurfaceVariant,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ],

                        // Korean Definition
                        _buildSectionHeader(
                            context, '뜻', Icons.menu_book_rounded),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                colorScheme.secondaryContainer.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colorScheme.outline.withOpacity(0.1),
                            ),
                          ),
                          child: definition == null || definition!.isEmpty
                              ? Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: colorScheme.outline,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '사전에 등록되지 않은 단어입니다.',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: colorScheme.outline,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  definition!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.7,
                                  ),
                                ),
                        ),

                        const SizedBox(height: 24),

                        // Synonyms
                        if (synonymsJson != null && synonymsJson!.isNotEmpty) ...[
                          _buildSectionHeader(context, '유의어', Icons.auto_awesome_rounded),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colorScheme.outline.withOpacity(0.1),
                              ),
                            ),
                            child: _buildWordList(context, synonymsJson!, colorScheme),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Antonyms
                        if (antonymsJson != null && antonymsJson!.isNotEmpty) ...[
                          _buildSectionHeader(context, '반의어', Icons.swap_horiz_rounded),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colorScheme.outline.withOpacity(0.1),
                              ),
                            ),
                            child: _buildWordList(context, antonymsJson!, colorScheme),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Usage examples from database
                        if (examplesJson != null && examplesJson!.isNotEmpty) ...[
                          _buildSectionHeader(context, '사용 예', Icons.format_quote_rounded),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colorScheme.outline.withOpacity(0.1),
                              ),
                            ),
                            child: _buildExamplesList(context, examplesJson!, colorScheme),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Usage examples from fullSenseInfo (examList2 and examList3)
                        if ((examList2 != null && examList2.isNotEmpty) ||
                            (examList3 != null && examList3.isNotEmpty)) ...[
                          if (examplesJson == null || examplesJson!.isEmpty)
                            _buildSectionHeader(context, '사용 예', Icons.format_quote_rounded),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colorScheme.outline.withOpacity(0.1),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Sentence examples (examList2)
                                if (examList2 != null &&
                                    examList2.isNotEmpty) ...[
                                  ...examList2.map((exam) {
                                    final example =
                                        exam['example']?.toString() ?? '';
                                    if (example.isEmpty)
                                      return const SizedBox.shrink();
                                    return _buildExampleItem(
                                        context, example, false);
                                  }).toList(),
                                ],
                                // Dialogue examples (examList3)
                                if (examList3 != null &&
                                    examList3.isNotEmpty) ...[
                                  if (examList2 != null && examList2.isNotEmpty)
                                    const SizedBox(height: 12),
                                  ...examList3.map((exam) {
                                    final example =
                                        exam['example']?.toString() ?? '';
                                    if (example.isEmpty)
                                      return const SizedBox.shrink();
                                    return _buildExampleItem(
                                        context, example, true);
                                  }).toList(),
                                ],
                              ],
                            ),
                          ),
                        ] else if (examplesJson == null || examplesJson!.isEmpty) ...[
                          // Fallback placeholder if no examples
                          _buildSectionHeader(
                              context, '사용 예', Icons.format_quote_rounded),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  color: colorScheme.tertiary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '이 단어는 문장에서 "$word"와 같이 사용됩니다.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
  }

  Widget _buildTagChip(
    BuildContext context,
    String label,
    ColorScheme colorScheme, {
    bool isSecondary = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildExampleItem(
    BuildContext context,
    String example,
    bool isDialogue,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isDialogue) ...[
            Container(
              margin: const EdgeInsets.only(top: 4, right: 10),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: colorScheme.tertiary,
                shape: BoxShape.circle,
              ),
            ),
          ] else ...[
            Icon(
              Icons.chat_bubble_outline,
              size: 16,
              color: colorScheme.tertiary.withOpacity(0.7),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              example,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                fontStyle: isDialogue ? FontStyle.italic : null,
                color: isDialogue
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurface,
              ),
            ),
          ),
        ],
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
      'EF': '종결 어미',
      'EC': '연결 어미',
      'ETN': '명사형 전성 어미',
      'ETM': '관형형 전성 어미',
      'JX': '보조사',
    };
    return descriptions[tag] ?? tag;
  }

  Widget _buildWordList(BuildContext context, String jsonStr, ColorScheme colorScheme) {
    try {
      final List<dynamic> wordList = json.decode(jsonStr);
      if (wordList.isEmpty) {
        return Text(
          '등록된 단어가 없습니다.',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant,
          ),
        );
      }
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: wordList.map((word) {
          return Chip(
            label: Text(word.toString()),
            backgroundColor: colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          );
        }).toList(),
      );
    } catch (e) {
      print('Error parsing word list JSON: $e');
      return Text(
        '데이터를 불러올 수 없습니다.',
        style: TextStyle(
          fontSize: 14,
          color: colorScheme.error,
        ),
      );
    }
  }

  Widget _buildExamplesList(BuildContext context, String jsonStr, ColorScheme colorScheme) {
    try {
      final List<dynamic> examplesList = json.decode(jsonStr);
      if (examplesList.isEmpty) {
        return Row(
          children: [
            Icon(Icons.info_outline, color: colorScheme.outline, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '등록된 예문이 없습니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: examplesList.map((example) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4, right: 10),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colorScheme.tertiary,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    example.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    } catch (e) {
      print('Error parsing examples JSON: $e');
      return Text(
        '예문을 불러올 수 없습니다.',
        style: TextStyle(
          fontSize: 14,
          color: colorScheme.error,
        ),
      );
    }
  }
}
