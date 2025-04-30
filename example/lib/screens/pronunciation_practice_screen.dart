import 'package:flutter/material.dart';
import 'package:speech_recognization_example/utils/numbers_and_words_list.dart';
import '../models/paragraph_data.dart';
import '../services/speech_recognition_service.dart';
import '../utils/extensions.dart';
import '../widgets/alphabet_practice.dart';
import '../widgets/language_selector.dart';
import '../widgets/paragraph_practice.dart';
import '../widgets/microphone_button.dart';
import '../widgets/result_display.dart';

class PronunciationPracticeScreen extends StatefulWidget {
  const PronunciationPracticeScreen({super.key});

  @override
  State<PronunciationPracticeScreen> createState() =>
      _PronunciationPracticeScreenState();
}

class _PronunciationPracticeScreenState
    extends State<PronunciationPracticeScreen> {
  final SpeechRecognitionService _speechService = SpeechRecognitionService();

  final ValueNotifier<String> _recognizedText = ValueNotifier('');
  final ValueNotifier<String> _selectedLanguage = ValueNotifier('en-US');
  final ValueNotifier<bool> _isListening = ValueNotifier(false);
  final ValueNotifier<int> _selectedParagraphIndex = ValueNotifier(0);
  final ValueNotifier<String> _currentAlphabet = ValueNotifier('');
  final ValueNotifier<List<String>> _spokenAlphabets = ValueNotifier([]);
  final ValueNotifier<String> _selectedPracticeMode = ValueNotifier('alphabets');

  final List<String> _languages = ['en-US', 'ja-JP', 'ko-KR', 'es-ES', 'fr-FR'];
  final List<String> _koreanChars = NumbersAndWordsList().koreanNumbers;
  final List<String> _japaneseChars = NumbersAndWordsList().japaneseKana;
  final List<String> _practiceModes = ['alphabets', 'paragraphs'];

  // Maintain an index tracker for each language
  final Map<String, int> _currentCharIndex = {
    'en-US': 0,
    'ko-KR': 0,
    'ja-JP': 0,
    'es-ES': 0,
    'fr-FR': 0,
  };

  final List<ParagraphData> _paragraphs = [
    ParagraphData(
      text:
      "The quick brown fox jumps over the lazy dog. She sells seashells by the seashore.",
      translation: "",
      language: "en-US",
    ),
    ParagraphData(
      text: "桜の花が咲く春が来ました。私は毎日公園で散歩をします。",
      translation:
      "Spring has come with cherry blossoms blooming. I walk in the park every day.",
      language: "ja-JP",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _setupLanguageListener();
    _generateNewAlphabet();
    _setupSpeechRecognition();
  }

  void _setupLanguageListener() {
    // Listen for language changes
    _selectedLanguage.addListener(() {
      _generateNewAlphabet(); // Generate a new alphabet for the new language
      _spokenAlphabets.value = []; // Reset spoken alphabets when language changes
    });
  }

  void _setupSpeechRecognition() {
    _speechService.recognitionStream.listen((event) {
      if (event.toString() == "RECOGNITION_ENDED") return;
      if (event.toString().startsWith("Error:")) {
        _recognizedText.value = event.toString();
        return;
      }
      _recognizedText.value = event.toString();
      _processRecognizedSpeech();
    }, onError: (error) {
      _recognizedText.value = "Error: ${error.toString()}";
      _isListening.value = false;
    });
  }

  void _processRecognizedSpeech() {
    if (_recognizedText.value.isEmpty) return;
    if (_selectedPracticeMode.value == 'alphabets') {
      final spoken = _recognizedText.value.trim().toLowerCase();
      if (spoken == _currentAlphabet.value.toLowerCase()) {
        _spokenAlphabets.value = [
          ..._spokenAlphabets.value,
          _currentAlphabet.value
        ];
        _generateNewAlphabet();
      }
    }
  }

  void _generateNewAlphabet() {
    // Choose alphabet based on current language
    final language = _selectedLanguage.value;

    if (language == 'ko-KR' && _koreanChars.isNotEmpty) {
      // Korean: pick next character sequentially
      _currentAlphabet.value = _koreanChars[_currentCharIndex[language]!];
      // Move to next index, wrap around if needed
      _currentCharIndex[language] = (_currentCharIndex[language]! + 1) % _koreanChars.length;
    } else if (language == 'ja-JP' && _japaneseChars.isNotEmpty) {
      // Japanese: pick next character sequentially
      _currentAlphabet.value = _japaneseChars[_currentCharIndex[language]!];
      // Move to next index, wrap around if needed
      _currentCharIndex[language] = (_currentCharIndex[language]! + 1) % _japaneseChars.length;
    } else {
      // English: use Latin alphabet A-Z sequentially
      _currentAlphabet.value = String.fromCharCode(65 + _currentCharIndex['en-US']!);
      // Move to next index, wrap around if needed (A-Z is 26 characters)
      _currentCharIndex['en-US'] = (_currentCharIndex['en-US']! + 1) % 26;
    }
  }

  Future<void> _startListening() async {
    try {
      _isListening.value = true;
      _recognizedText.value = "";

      String mode;
      if (_selectedPracticeMode.value == 'alphabets') {
        mode = 'alphabets';
      } else if (_selectedPracticeMode.value == 'paragraphs') {
        mode = 'targeted';
      } else {
        mode = 'continuous';
      }

      await _speechService.startRecognition(
        language: _selectedLanguage.value,
        mode: mode,
        targetText: _selectedPracticeMode.value == 'alphabets'
            ? _currentAlphabet.value
            : null,
      );
    } catch (e) {
      _recognizedText.value = "Error: ${e.toString()}";
      _isListening.value = false;
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speechService.stopRecognition();
      _isListening.value = false;
    } catch (e) {
      _recognizedText.value = "Error: ${e.toString()}";
      _isListening.value = false;
    }
  }

  String _langName(String code) {
    return {
      'en-US': 'English',
      'ja-JP': 'Japanese',
      'ko-KR': 'Korean',
      'es-ES': 'Spanish',
      'fr-FR': 'French',
    }[code] ??
        'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("IOS SPEECH RECOGNIZER"),
        actions: [
          ValueListenableBuilder<String>(
            valueListenable: _selectedPracticeMode,
            builder: (context, mode, _) {
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: DropdownButton<String>(
                  value: mode,
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  onChanged: _isListening.value
                      ? null
                      : (v) => _selectedPracticeMode.value = v!,
                  items: _practiceModes
                      .map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(m.capitalize()),
                  ))
                      .toList(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            LanguageSelector(
              languages: _languages,
              selectedLanguage: _selectedLanguage,
              isListening: _isListening.value,
              langNameFn: _langName,
            ),
            const SizedBox(height: 30),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: _selectedPracticeMode,
                builder: (context, mode, _) {
                  if (mode == 'alphabets') {
                    return AlphabetPractice(
                      currentAlphabet: _currentAlphabet,
                      spokenAlphabets: _spokenAlphabets,
                    );
                  }
                  return ParagraphPractice(
                    paragraph: _paragraphs[_selectedParagraphIndex.value],
                  );
                },
              ),
            ),
            const SizedBox(height: 30),
            MicrophoneButton(
              isListening: _isListening,
              onTapDown: _startListening,
              onTapUp: _stopListening,
              onTapCancel: _stopListening,
            ),
            const SizedBox(height: 20),
            ResultDisplay(recognizedText: _recognizedText),
          ],
        ),
      ),
    );
  }
}