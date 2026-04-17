## Issue Fixed: Kiwi Initialization Race Condition

### Problem
The Flutter app was calling `isReady()` method before Kiwi initialization completed in the background thread, causing "Kiwi 초기화에 실패했습니다" (Kiwi initialization failed) error.

### Root Cause
- `MainActivity.configureFlutterEngine()` starts Kiwi initialization in a background thread
- The Flutter provider immediately calls `isReady()` after the channel is set up
- The `isReady()` call returns `false` because initialization hasn't completed yet

### Solution
Modified `MainActivity.kt` to:
1. Added `kiwiInitializing` flag to track initialization state
2. In the `isReady` method handler, wait for initialization to complete (with 5 second timeout)
3. Only return the result after initialization completes or timeout occurs

### Files Changed
- `/workspace/android/app/src/main/java/com/example/kor_analyzer/MainActivity.kt`