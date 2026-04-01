// lib/providers/korean_reader_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_kiwi_nlp/flutter_kiwi_nlp.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/analysis_result.dart';
import '../services/dictionary_service.dart';

class KoreanReaderProvider extends ChangeNotifier {
  Kiwi? _kiwi;
  bool _isInitialized = false;
  String _errorMessage = '';
  List<AnalysisResult> _currentResults = [];
  bool _isAnalyzing = false;
  final DictionaryService _dictionaryService = DictionaryService();

  bool get isInitialized => _isInitialized;
  String get errorMessage => _errorMessage;
  List<AnalysisResult> get currentResults => _currentResults;
  bool get isAnalyzing => _isAnalyzing;

  KoreanReaderProvider() {
    initializeKiwi();
  }

  Future<void> initializeKiwi() async {
    try {
      _kiwi = Kiwi();
      
      // Check if model exists, if not download
      final modelPath = await _getModelPath();
      if (!await File(modelPath).exists()) {
        await _downloadModel();
      }
      
      await _kiwi!.loadModel(modelPath);
      _isInitialized = true;
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Kiwi 초기화 실패: $e';
      _isInitialized = false;
      notifyListeners();
    }
  }

  Future<String> _getModelPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/kiwi_model/base';
  }

  Future<void> _downloadModel() async {
    // Download model from GitHub releases
    // For simplicity, we'll assume model is included in assets
    // In production, you'd download from: 
    // https://github.com/bab2min/Kiwi/releases
    _errorMessage = '모델 파일이 필요합니다. 앱을 다시 설치해주세요.';
    throw Exception('Model not found');
  }

  Future<void> analyzeText(String text) async {
    if (!_isInitialized || _kiwi == null) {
      _errorMessage = '분석기가 초기화되지 않았습니다.';
      notifyListeners();
      return;
    }

    if (text.trim().isEmpty) {
      _currentResults = [];
      notifyListeners();
      return;
    }

    _isAnalyzing = true;
    notifyListeners();

    try {
      // Analyze using Kiwi
      final analysis = await _kiwi!.analyze(text);
      
      // Parse results - Kiwi returns List<List<Morpheme>>
      final List<AnalysisResult> results = [];
      
      // Split into eojeol (word chunks) and analyze
      final words = text.split(RegExp(r'\s+'));
      int index = 1;
      
      for (var word in words) {
        final analysis = await _kiwi!.analyze(word);
        final morphemes = analysis.first; // Take first analysis result
        
        results.add(AnalysisResult(
          index: index,
          originalForm: word,
          morphemes: morphemes.map((m) => Morpheme(
            text: m.form,
            tag: m.tag,
          )).toList(),
        ));
        index++;
      }
      
      _currentResults = results;
      _errorMessage = '';
    } catch (e) {
      _errorMessage = '분석 중 오류 발생: $e';
      _currentResults = [];
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  Future<String?> getDefinition(String word, String tag) async {
    return await _dictionaryService.getDefinition(word, tag);
  }

  void clearResults() {
    _currentResults = [];
    notifyListeners();
  }
}