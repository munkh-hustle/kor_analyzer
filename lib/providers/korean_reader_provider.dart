// lib/providers/korean_reader_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../models/analysis_result.dart';
import '../services/dictionary_service.dart';

class KoreanReaderProvider extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('korean_reader/kiwi');
  
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
    initialize();
  }

  Future<void> initialize() async {
    try {
      print('Checking if Kiwi is ready...');
      final isReady = await _channel.invokeMethod('isReady');
      _isInitialized = isReady == true;
      
      if (!_isInitialized) {
        _errorMessage = 'Kiwi 초기화에 실패했습니다.';
        print('Kiwi initialization failed');
      } else {
        print('Kiwi initialized successfully');
      }
      
      notifyListeners();
    } catch (e) {
      _errorMessage = '초기화 오류: $e';
      _isInitialized = false;
      print('Initialization error: $e');
      notifyListeners();
    }
  }

  Future<void> analyzeText(String text) async {
    if (!_isInitialized) {
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
    _errorMessage = '';
    notifyListeners();

    try {
      print('Analyzing text: $text');
      final String resultsJson = await _channel.invokeMethod(
        'analyzeText',
        {'text': text},
      );
      
      print('Analysis result: $resultsJson');
      final List<dynamic> resultsList = json.decode(resultsJson);
      final List<AnalysisResult> analysisResults = [];
      
      for (var result in resultsList) {
        final morphemes = (result['morphemes'] as List).map((m) => Morpheme(
          text: m['text'] as String,
          tag: m['tag'] as String,
        )).toList();
        
        analysisResults.add(AnalysisResult(
          index: result['index'] as int,
          originalForm: result['originalForm'] as String,
          morphemes: morphemes,
        ));
      }
      
      _currentResults = analysisResults;
      print('Analysis complete. Found ${analysisResults.length} words');
    } on PlatformException catch (e) {
      _errorMessage = '분석 중 오류 발생: ${e.message}';
      print('Platform exception: ${e.message}');
      _currentResults = [];
    } catch (e) {
      _errorMessage = '분석 중 오류 발생: $e';
      print('Analysis error: $e');
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