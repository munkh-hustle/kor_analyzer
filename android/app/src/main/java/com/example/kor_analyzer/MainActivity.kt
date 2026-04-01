package com.example.kor_analyzer

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result

class MainActivity : FlutterActivity() {
    private val CHANNEL = "korean_reader/kiwi"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize Kiwi
        try {
            KiwiAnalyzer.initialize(applicationContext)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        // Set up method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: Result ->
                when (call.method) {
                    "analyzeText" -> {
                        val text = call.argument<String>("text")
                        if (text == null) {
                            result.error("INVALID_ARGUMENT", "Text is required", null)
                            return@setMethodCallHandler
                        }
                        
                        try {
                            val analysisResults = KiwiAnalyzer.analyzeText(text)
                            result.success(analysisResults)
                        } catch (e: Exception) {
                            result.error("ANALYSIS_ERROR", e.message, null)
                        }
                    }
                    "isReady" -> {
                        result.success(KiwiAnalyzer.isReady())
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }
}