# Spaced Repetition System (SRS) - Flashcard Mode Implementation

## Overview
This implementation adds an Anki-style Spaced Repetition System to your Korean Reader app. The system allows users to create flashcards from analyzed text, with each flashcard containing both the word AND the full paragraph context for better learning retention.

## Key Features

### 1. **Flashcard Model** (`lib/models/flashcard.dart`)
- Stores complete paragraph context along with individual words
- Implements SM-2 algorithm fields (Anki-style):
  - `interval`: Days until next review
  - `easeFactor`: Difficulty multiplier (starts at 2.5)
  - `repetitions`: Number of successful reviews
  - `nextReviewAt`: When the card is due

### 2. **Flashcard Service** (`lib/services/flashcard_service.dart`)
- SQLite-based persistent storage (survives app closes)
- Key methods:
  - `createFlashcard()`: Create new flashcard from history entry
  - `getDueFlashcards()`: Get cards due for review (Anki-style queue)
  - `updateFlashcardAfterReview()`: Apply SM-2 algorithm after review
  - `deleteFlashcardsByParagraph()`: Clean up when history is deleted

### 3. **SM-2 Algorithm Implementation**
The system uses the proven SM-2 algorithm (same as Anki):
- Quality ratings: 0-5 (Again, Hard, Good, Easy)
- Failed cards (quality < 3): Reset to interval = 1 day
- Successful cards: Interval grows exponentially
- Ease factor adjusts based on performance

### 4. **Flashcard Review Screen** (`lib/screens/flashcard_review_screen.dart`)
- Shows full paragraph context at top
- Word in focus displayed prominently
- Definition revealed on button tap
- 4-button rating system (Again/Hard/Good/Easy)
- Session statistics (correct/incorrect/accuracy)
- Progress indicator

### 5. **Integration Points**

#### Creating Flashcards
- Long-press any morpheme chip in analysis results
- Each flashcard automatically links to its source paragraph
- Prevents duplicate flashcards for same word+paragraph

#### History Screen Updates
- Added flashcard icon with badge showing due count
- Deleting history also deletes associated flashcards
- Clear all history clears all flashcards

#### Text Input Screen
- Saves paragraph ID when analyzing text
- Passes paragraph ID and text to AnalysisResultWidget
- Enables flashcard creation from analysis results

## Data Flow

```
User inputs Korean text
    ↓
Text is analyzed → Results displayed with morpheme chips
    ↓
History saved → Returns paragraph ID
    ↓
User long-presses word → Flashcard created
    ↓
Flashcard stored in SQLite with:
  - Full paragraph text
  - Word and tag
  - Definition (if available)
  - SRS scheduling data
    ↓
When user opens History screen:
  - Badge shows due flashcards count
  - Tap flashcard icon → Review session starts
    ↓
During review:
  - Shows paragraph context
  - Shows word
  - User taps to see definition
  - User rates recall (Again/Hard/Good/Easy)
  - SM-2 calculates next review date
    ↓
Data persists in phone storage
```

## Database Schema

### Flashcards Table
```sql
CREATE TABLE flashcards (
  id TEXT PRIMARY KEY,
  paragraphId TEXT NOT NULL,
  paragraph TEXT NOT NULL,
  word TEXT NOT NULL,
  tag TEXT NOT NULL,
  definition TEXT,
  createdAt INTEGER NOT NULL,
  interval INTEGER NOT NULL DEFAULT 0,
  easeFactor REAL NOT NULL DEFAULT 2.5,
  repetitions INTEGER NOT NULL DEFAULT 0,
  lastReviewedAt INTEGER NOT NULL,
  nextReviewAt INTEGER NOT NULL
)
```

## Usage Instructions

### For End Users:
1. **Create Flashcards**: 
   - Enter Korean text and analyze it
   - Long-press any word chip to add to flashcards
   
2. **Review Flashcards**:
   - Go to History screen
   - Tap the school icon (badge shows due count)
   - Rate each card: Again/Hard/Good/Easy
   
3. **Data Persistence**:
   - All flashcards are saved to phone storage
   - Data survives app closes and restarts
   - Deleting history removes associated flashcards

### For Developers:
- Flashcard creation: `FlashcardService().createFlashcard(...)`
- Get due cards: `FlashcardService().getDueFlashcards(limit: 20)`
- Update after review: `FlashcardService().updateFlashcardAfterReview(id, quality)`
- Check existence: `FlashcardService().exists(paragraphId, word)`

## Files Added/Modified

### New Files:
- `lib/models/flashcard.dart` - Flashcard data model
- `lib/services/flashcard_service.dart` - SRS service layer
- `lib/screens/flashcard_review_screen.dart` - Review UI

### Modified Files:
- `lib/widgets/analysis_result_widget.dart` - Added long-press for flashcard creation
- `lib/screens/text_input_screen.dart` - Added paragraph ID tracking
- `lib/screens/history_screen.dart` - Added flashcard review button with badge
- `lib/services/history_service.dart` - Changed saveHistory to return ID

## Benefits

1. **Context-Based Learning**: Unlike traditional flashcards, students see the full paragraph, not just isolated words
2. **Proven Algorithm**: SM-2 algorithm optimizes review timing for maximum retention
3. **Persistent Storage**: SQLite ensures no data loss when app closes
4. **Seamless Integration**: Works with existing history and analysis features
5. **Automatic Cleanup**: Flashcards are removed when source history is deleted
