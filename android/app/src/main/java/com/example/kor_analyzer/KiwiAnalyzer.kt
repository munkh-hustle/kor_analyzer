package com.example.kor_analyzer

import android.content.Context
import android.util.Log
import kr.pe.bab2min.Kiwi
import kr.pe.bab2min.KiwiBuilder
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream

class KiwiAnalyzer private constructor() {
    companion object {
        private const val TAG = "KiwiAnalyzer"
        private var instance: Kiwi? = null
        private var isInitialized = false
        private var defaultOption: Kiwi.AnalyzeOption? = null
        
        fun initialize(context: Context) {
            if (isInitialized) {
                Log.d(TAG, "Kiwi already initialized")
                return
            }
            
            try {
                Log.d(TAG, "Starting Kiwi initialization...")
                
                // Get the default analyze option
                defaultOption = getDefaultAnalyzeOption()
                Log.d(TAG, "Default analyze option: $defaultOption")
                
                // Copy model files from assets to app storage
                val modelDir = File(context.filesDir, "kiwi_model")
                if (!modelDir.exists()) {
                    modelDir.mkdirs()
                    Log.d(TAG, "Created model directory: ${modelDir.absolutePath}")
                }
                
                // Copy all model files
                val modelFiles = listOf("cong.mdl", "default.dict", "dialect.dict", 
                                       "extract.mdl", "multi.dict", "nounchr.mdl", 
                                       "sj.morph", "typo.dict", "combiningRule")
                
                var copiedCount = 0
                for (fileName in modelFiles) {
                    val destFile = File(modelDir, fileName)
                    if (!destFile.exists()) {
                        try {
                            Log.d(TAG, "Copying $fileName")
                            context.assets.open("models/kiwi/$fileName").use { inputStream ->
                                FileOutputStream(destFile).use { outputStream ->
                                    val buffer = ByteArray(8192)
                                    var length: Int
                                    while (inputStream.read(buffer).also { length = it } > 0) {
                                        outputStream.write(buffer, 0, length)
                                    }
                                }
                            }
                            copiedCount++
                        } catch (e: Exception) {
                            Log.w(TAG, "Could not copy $fileName: ${e.message}")
                        }
                    } else {
                        copiedCount++
                    }
                }
                
                Log.d(TAG, "Copied $copiedCount model files")
                
                // Initialize Kiwi with file path
                Log.d(TAG, "Loading Kiwi from: ${modelDir.absolutePath}")
                instance = Kiwi.init(modelDir.absolutePath)
                isInitialized = true
                Log.d(TAG, "✅ Kiwi initialized successfully")
                
                // Test analysis
                testAnalysis()
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize Kiwi", e)
                throw RuntimeException("Kiwi initialization failed", e)
            }
        }
        
        private fun getDefaultAnalyzeOption(): Kiwi.AnalyzeOption {
            return try {
                // Create a new AnalyzeOption instance with default values
                Kiwi.AnalyzeOption()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to create analyze option", e)
                throw e
            }
        }
        
        private fun testAnalysis() {
            try {
                if (instance != null && defaultOption != null) {
                    val testTokens = instance!!.tokenize("테스트", defaultOption)
                    Log.d(TAG, "Test analysis successful: ${testTokens.size} tokens")
                    for (token in testTokens) {
                        Log.d(TAG, "  Token: ${token.form} / ${Kiwi.POSTag.toString(token.tag)}")
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Test analysis failed but initialization succeeded", e)
            }
        }
        
        fun analyzeText(text: String): String {
            if (!isInitialized || instance == null) {
                Log.e(TAG, "Kiwi not initialized, cannot analyze text")
                return JSONArray().toString()
            }
            
            try {
                Log.d(TAG, "Analyzing text: '$text'")
                
                // Split into eojeol (word chunks)
                val words = text.split(Regex("\\s+")).filter { it.isNotBlank() }
                val resultsArray = JSONArray()
                var index = 1
                
                for (word in words) {
                    Log.d(TAG, "Analyzing word $index: '$word'")
                    
                    // Analyze each word using tokenize with default option
                    val tokens = if (defaultOption != null) {
                        instance!!.tokenize(word, defaultOption)
                    } else {
                        // This should never happen as we set defaultOption in initialize
                        val fallbackOption = Kiwi.AnalyzeOption()
                        instance!!.tokenize(word, fallbackOption)
                    }
                    
                    val morphemesArray = JSONArray()
                    for (token in tokens) {
                        val tagString = Kiwi.POSTag.toString(token.tag)
                        Log.d(TAG, "  Token: ${token.form} / $tagString")
                        
                        val morphemeObj = JSONObject().apply {
                            put("text", token.form)
                            put("tag", tagString)
                        }
                        morphemesArray.put(morphemeObj)
                    }
                    
                    val resultObj = JSONObject().apply {
                        put("index", index)
                        put("originalForm", word)
                        put("morphemes", morphemesArray)
                    }
                    
                    resultsArray.put(resultObj)
                    index++
                }
                
                val result = resultsArray.toString()
                Log.d(TAG, "Analysis complete. Found ${index - 1} words")
                return result
                
            } catch (e: Exception) {
                Log.e(TAG, "Analysis error", e)
                return JSONArray().toString()
            }
        }
        
        fun isReady(): Boolean {
            val ready = isInitialized && instance != null
            Log.d(TAG, "isReady: $ready")
            return ready
        }
    }
}