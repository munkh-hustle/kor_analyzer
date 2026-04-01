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
        
        fun initialize(context: Context) {
            if (isInitialized) return
            
            try {
                // Method 1: Using StreamProvider to read from assets directly (recommended)
                val streamProvider = KiwiBuilder.StreamProvider { filename ->
                    try {
                        // Open model files from assets
                        context.assets.open("models/kiwi/$filename")
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to open $filename from assets", e)
                        null
                    }
                }
                
                // Build Kiwi instance with the stream provider
                val builder = KiwiBuilder(streamProvider)
                instance = builder.build()
                
                if (instance != null) {
                    isInitialized = true
                    Log.d(TAG, "Kiwi initialized successfully from assets")
                } else {
                    Log.e(TAG, "Failed to build Kiwi instance")
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize Kiwi", e)
                // Fallback: Try copying from assets to files directory
                tryFallbackInitialization(context)
            }
        }
        
        private fun tryFallbackInitialization(context: Context) {
            try {
                // Copy model files from assets to app storage
                val modelDir = File(context.filesDir, "kiwi_model")
                if (!modelDir.exists()) {
                    modelDir.mkdirs()
                }
                
                val modelFiles = listOf("base.dict", "base.mmap", "base.syn")
                
                for (fileName in modelFiles) {
                    val destFile = File(modelDir, fileName)
                    if (!destFile.exists()) {
                        context.assets.open("models/kiwi/$fileName").use { inputStream ->
                            FileOutputStream(destFile).use { outputStream ->
                                val buffer = ByteArray(1024)
                                var length: Int
                                while (inputStream.read(buffer).also { length = it } > 0) {
                                    outputStream.write(buffer, 0, length)
                                }
                            }
                        }
                        Log.d(TAG, "Copied $fileName to ${destFile.absolutePath}")
                    }
                }
                
                // Initialize Kiwi with file path
                instance = Kiwi.init(modelDir.absolutePath)
                isInitialized = true
                Log.d(TAG, "Kiwi initialized successfully from files: ${modelDir.absolutePath}")
                
            } catch (e: Exception) {
                Log.e(TAG, "Fallback initialization also failed", e)
                throw RuntimeException("Kiwi initialization failed", e)
            }
        }
        
        fun analyzeText(text: String): String {
            if (!isInitialized || instance == null) {
                Log.e(TAG, "Kiwi not initialized")
                return JSONArray().toString()
            }
            
            try {
                // Split into eojeol (word chunks)
                val words = text.split(Regex("\\s+")).filter { it.isNotBlank() }
                val resultsArray = JSONArray()
                var index = 1
                
                for (word in words) {
                    // Analyze each word using Kiwi's tokenize method
                    val tokens = instance!!.tokenize(word, Kiwi.Match.allWithNormalizing)
                    
                    val morphemesArray = JSONArray()
                    for (token in tokens) {
                        val morphemeObj = JSONObject().apply {
                            put("text", token.form)
                            put("tag", Kiwi.POSTag.toString(token.tag))
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
                
                return resultsArray.toString()
                
            } catch (e: Exception) {
                Log.e(TAG, "Analysis error", e)
                return JSONArray().toString()
            }
        }
        
        fun isReady(): Boolean = isInitialized
    }
}