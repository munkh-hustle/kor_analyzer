// lib/models/analysis_result.dart
class AnalysisResult {
  final int index;
  final String originalForm;
  final List<Morpheme> morphemes;

  AnalysisResult({
    required this.index,
    required this.originalForm,
    required this.morphemes,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'originalForm': originalForm,
    'morphemes': morphemes.map((m) => m.toJson()).toList(),
  };

  factory AnalysisResult.fromJson(Map<String, dynamic> json) => AnalysisResult(
    index: json['index'],
    originalForm: json['originalForm'],
    morphemes: (json['morphemes'] as List)
        .map((m) => Morpheme.fromJson(m))
        .toList(),
  );
}

class Morpheme {
  final String text;
  final String tag;

  Morpheme({
    required this.text,
    required this.tag,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'tag': tag,
  };

  factory Morpheme.fromJson(Map<String, dynamic> json) => Morpheme(
    text: json['text'],
    tag: json['tag'],
  );

  String getTagDescription() {
    final descriptions = {
      'NNG': '일반 명사',
      'NNP': '고유 명사',
      'NNB': '의존 명사',
      'NR': '수사',
      'NP': '대명사',
      'VV': '동사',
      'VA': '형용사',
      'VX': '보조 용언',
      'VCP': '긍정 지정사(이다)',
      'VCN': '부정 지정사(아니다)',
      'MM': '관형사',
      'MAG': '일반 부사',
      'MAJ': '접속 부사',
      'IC': '감탄사',
      'JKS': '주격 조사',
      'JKC': '보격 조사',
      'JKG': '관형격 조사',
      'JKO': '목적격 조사',
      'JKB': '부사격 조사',
      'JKV': '호격 조사',
      'JKQ': '인용격 조사',
      'JX': '보조사',
      'JC': '접속 조사',
      'EP': '선어말 어미',
      'EF': '종결 어미',
      'EC': '연결 어미',
      'ETN': '명사형 전성 어미',
      'ETM': '관형형 전성 어미',
      'XPN': '체언 접두사',
      'XSN': '명사 파생 접미사',
      'XSV': '동사 파생 접미사',
      'XSA': '형용사 파생 접미사',
      'XR': '어근',
      'SF': '종결 부호',
      'SP': '구분 부호',
      'SS': '인용 부호',
      'SL': '알파벳',
      'SH': '한자',
      'SN': '숫자',
    };
    return descriptions[tag] ?? '기타';
  }
}