# Korean Reader App

A Flutter-based Korean language learning application that provides instant morphological analysis and dictionary definitions for Korean text, working completely offline once the dictionary is downloaded.

## Features

- **Text Input**: Manual text entry for Korean sentences
- **Morphological Analysis**: Automatically splits Korean text into individual morphemes with part-of-speech tags
- **Stemming**: Converts conjugated forms to dictionary base forms
- **Particle Detection**: Separates grammatical particles from content words
- **Dictionary Lookup**: Tap any morpheme to see its definition
- **Offline Operation**: Works entirely offline after initial dictionary download

## Technical Implementation

### Core Components

1. **Kiwi Morphological Analyzer** (`flutter_kiwi_nlp` package)
   - Provides accurate Korean morphological analysis
   - Handles stemming and particle detection
   - Offline operation with pre-downloaded models

2. **SQLite Database** (`sqflite` package)
   - Stores dictionary definitions
   - Supports custom user additions
   - Efficient offline lookup

3. **Flutter UI**
   - Clean, intuitive interface
   - Visual display of analysis results
   - Interactive word definitions

### Architecture
lib/
├── main.dart # App entry point
├── models/
│ └── analysis_result.dart # Data models for analysis results
├── providers/
│ └── korean_reader_provider.dart # State management
├── screens/
│ └── text_input_screen.dart # Main input screen
├── services/
│ └── dictionary_service.dart # Dictionary database service
└── widgets/
├── analysis_result_widget.dart # Results display
└── dictionary_popup.dart # Definition popup


## Installation

### Prerequisites
- Flutter SDK (>=3.0.0)
- Android SDK (for Android development)
- Android API Level 21+ (minimum)

### Steps
1. **Clone the repository**
```bash
git clone https://github.com/yourusername/korean_reader.git
cd korean_reader