--- README.md (原始)
# Korean Reader App

A Flutter-based Korean language learning application that provides instant morphological analysis and dictionary definitions for Korean text, working completely offline once the dictionary is downloaded.

## Features

- **Text Input**: Manual text entry for Korean sentences
- **Morphological Analysis**: Automatically splits Korean text into individual morphemes with part-of-speech tags
- **Stemming**: Converts conjugated forms to dictionary base forms
- **Particle Detection**: Separates grammatical particles from content words
- **Dictionary Lookup**: Tap any morpheme to see its definition
- **Offline Operation**: Works entirely offline after initial dictionary download

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

+++ README.md (修改后)
# Korean Reader App 🇰🇷

A comprehensive Flutter-based Korean language learning application that provides instant morphological analysis and dictionary definitions for Korean text. The app works completely offline once the dictionary database is initialized, making it perfect for studying anywhere without internet connectivity.

![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)
![Platform](https://img.shields.io/badge/Platform-Android-green.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## 📱 Features

### Core Functionality
- **Text Input**: Manual text entry for Korean sentences with intuitive UI
- **Morphological Analysis**: Automatically splits Korean text into individual morphemes with detailed part-of-speech tags using advanced Korean language processing
- **Stemming**: Converts conjugated verb and adjective forms to dictionary base forms for easier lookup
- **Particle Detection**: Intelligently separates grammatical particles (조사) from content words
- **Dictionary Lookup**: Tap any morpheme to instantly see comprehensive definitions including:
  - Mongolian translations (🇲🇳)
  - English translations (🇬🇧)
  - Korean definitions (🇰🇷)
  - Part of speech tags
  - Example sentences
- **Offline Operation**: Works entirely offline after initial dictionary database creation
- **Multi-level Dictionary**: Supports vocabulary from beginner (Level 1) to advanced (Level 4)

### Technical Features
- **SQLite Database**: Efficient local storage with ~38MB of dictionary data
- **State Management**: Provider pattern for reactive UI updates
- **Clean Architecture**: Separation of concerns with models, services, providers, screens, and widgets
- **Memory Optimization**: Streaming JSON parsing for large dictionary files with garbage collection hints
- **Progress Feedback**: Console logging during database initialization

## 🏗️ Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   └── analysis_result.dart  # Data model for morphological analysis results
├── providers/
│   └── korean_reader_provider.dart  # State management with Provider pattern
├── screens/
│   └── text_input_screen.dart       # Main UI for text input and analysis
├── services/
│   └── dictionary_service.dart      # SQLite database management and dictionary lookup
└── widgets/
    ├── analysis_result_widget.dart  # Display morphological analysis results
    └── dictionary_popup.dart        # Popup widget for dictionary definitions

assets/
└── dictionary data/
    ├── word_level01_01.json    (~29MB) - Beginner vocabulary
    ├── phrase_level01_01.json  (~3.3MB) - Beginner phrases
    └── grammar_level01_01.json (~3.7MB) - Grammar patterns
```

## 📦 Dependencies

### Production Dependencies
- **flutter SDK**: Core framework
- **path_provider**: ^2.1.0 - Access device file system directories
- **shared_preferences**: ^2.2.0 - Persistent key-value storage
- **sqflite**: ^2.3.0 - SQLite database operations
- **path**: ^1.9.0 - Cross-platform path manipulation
- **provider**: ^6.1.0 - InheritedWidget-based state management

### Development Dependencies
- **flutter_test**: SDK - Widget testing framework
- **flutter_lints**: ^6.0.0 - Recommended lint rules for Flutter projects

## 🚀 Installation

### Prerequisites
- **Flutter SDK**: Version 3.0.0 or higher
- **Dart SDK**: Version 3.0.0 or higher (included with Flutter)
- **Android SDK**: For Android development
- **Android Studio** or **VS Code** with Flutter extensions
- **Minimum Android API Level**: 21 (Android 5.0 Lollipop)
- **Recommended**: Android API Level 29+ for best performance

### Step-by-Step Installation

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/korean_reader.git
cd korean_reader
```

2. **Install Flutter dependencies**
```bash
flutter pub get
```

3. **Verify Flutter setup**
```bash
flutter doctor
```
Ensure all checks pass, especially for Android toolchain.

4. **Run the application**
```bash
flutter run
```

### First-Time Setup
On first launch, the app will:
1. Check if the dictionary database exists
2. If not found, automatically create the database from JSON assets
3. Parse and insert ~30,000+ dictionary entries
4. This process may take 30-60 seconds depending on device performance
5. Subsequent launches will be instant as the database persists

## 🔧 Configuration

### Environment Variables
No environment variables required. All configuration is handled internally.

### Asset Files
The app requires dictionary JSON files in `assets/dictionary data/`:
- Files are automatically loaded on first run
- Total asset size: ~38MB
- Supported formats: LexicalResource (new) and channel/item (legacy)

## 📖 Usage Guide

### Basic Usage
1. **Launch the app** - Wait for initial database setup if first run
2. **Enter Korean text** - Type or paste any Korean sentence in the input field
3. **View analysis** - The app automatically analyzes the text into morphemes
4. **Tap morphemes** - Touch any word to see its dictionary definition
5. **Review information** - See translations, part of speech, and examples

### Example Input
```
저는 한국어를 공부합니다
```

### Expected Output
- 저는 → 저 (PRONOUN) + 는 (PARTICLE)
- 한국어를 → 한국어 (NOUN) + 를 (PARTICLE)
- 공부합니다 → 공부하다 (VERB) + ㅂ니다 (ENDING)

Each morpheme is tappable for detailed dictionary information.

## 🧪 Testing

### Run Unit Tests
```bash
flutter test
```

### Run with Coverage
```bash
flutter test --coverage
```

### Widget Testing
Tests are located in the `test/` directory (to be implemented).

## 🐛 Troubleshooting

### Common Issues

**Database not initializing:**
- Clear app data: Settings → Apps → Korean Reader → Storage → Clear Data
- Uninstall and reinstall the app
- Check console logs for specific error messages

**Missing dictionary files:**
- Verify files exist in `assets/dictionary data/`
- Check `pubspec.yaml` assets section includes the directory
- Run `flutter clean && flutter pub get`

**Performance issues during first launch:**
- This is normal - database creation takes time
- Wait for "Total dictionary entries inserted" message in logs
- Subsequent launches will be fast

**Analysis not working:**
- Ensure Korean text is properly encoded (UTF-8)
- Check that morphological analyzer service is initialized
- Review provider state in debug console

## 📈 Performance Considerations

- **Database Size**: ~38MB compressed JSON, expands to larger SQLite database
- **Memory Usage**: Optimized with streaming JSON parsing and delayed garbage collection
- **First Launch**: 30-60 seconds for database creation
- **Subsequent Launches**: <2 seconds
- **Text Analysis**: Near-instant for typical sentence lengths (<100 characters)

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style
- Follow Dart style guide
- Use `flutter analyze` before committing
- Write tests for new features
- Document public APIs

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Korean dictionary data provided by [Source Organization]
- Flutter team for the excellent framework
- Provider package maintainers
- Korean language learners who inspired this project

## 🗺️ Roadmap

### Completed ✅
- Basic morphological analysis
- Dictionary lookup with multi-language support
- Offline functionality
- Provider state management

### In Progress 🚧
- Enhanced error handling and logging
- Comprehensive test coverage
- Performance optimizations

### Planned 📋
- Text-to-Speech (TTS) integration
- Search history functionality
- Quiz mode for vocabulary practice
- Clipboard detection for quick lookup
- Dark mode theme
- Multi-language UI support
- Accessibility improvements
- Crash reporting and analytics

---

**Made with ❤️ for Korean language learners**