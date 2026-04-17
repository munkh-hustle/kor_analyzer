package com.example.kor_analyzer

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result

class MainActivity : FlutterActivity() {
    private val CHANNEL = "korean_reader/kiwi"
    private var kiwiInitializing = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize Kiwi in background thread to avoid blocking UI
        Thread {
            try {
                println("=== Starting Kiwi initialization from MainActivity ===")
                KiwiAnalyzer.initialize(applicationContext)
                println("=== Kiwi initialization completed successfully ===")
            } catch (e: Exception) {
                println("=== Kiwi initialization FAILED: ${e.message} ===")
                e.printStackTrace()
            }
        }.start()
        kiwiInitializing = true

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
                        // Wait for initialization to complete (with timeout)
                        if (kiwiInitializing && !KiwiAnalyzer.isReady()) {
                            var waitCount = 0
                            while (kiwiInitializing && !KiwiAnalyzer.isReady() && waitCount < 50) {
                                try {
                                    Thread.sleep(100) // Wait up to 5 seconds
                                    waitCount++
                                } catch (e: InterruptedException) {
                                    break
                                }
                            }
                        }
                        
                        val ready = KiwiAnalyzer.isReady()
                        println("=== isReady called, returning: $ready ===")
                        if (!ready) {
                            val error = KiwiAnalyzer.getInitializationError()
                            if (error != null) {
                                println("=== Initialization error details: $error ===")
                            }
                        }
                        result.success(ready)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }
}
