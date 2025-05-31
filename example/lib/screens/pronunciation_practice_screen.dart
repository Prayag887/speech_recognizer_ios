import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_recognization/speech_recognization.dart';
import 'package:speech_recognization_example/utils/numbers_and_words_list.dart';
import '../models/paragraph_data.dart';
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
  final SpeechRecognizerIos _speechService = SpeechRecognizerIos();

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
      "I visited Bandipur, a small hill town. The streets were clean with old houses and stone paths. I walked around and saw beautiful views of the mountains. People were friendly and smiling. I ate local food and watched the sunset from the hill. Bandipur was peaceful and quiet",
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

      // Handle structured data from iOS plugin
      if (event is Map) {
        if (event.containsKey('error')) {
          _recognizedText.value = "Error: ${event['error']}";
          return;
        }

        if (event.containsKey('status')) {
          return;
        }

        final text = event['text']?.toString() ?? '';
        final isFinal = event['isFinal'] == true;

        if (_selectedPracticeMode.value == 'alphabets') {
          // For alphabets, only process final results
          if (isFinal) {
            _recognizedText.value = text;
            _processRecognizedSpeech();
          }
        } else {
          _recognizedText.value = text;
        }
      } else {
        // Handle legacy string responses
        if (event.toString().startsWith("Error:")) {
          _recognizedText.value = event.toString();
          return;
        }
        _recognizedText.value = event.toString();
        if (_selectedPracticeMode.value == 'alphabets') {
          _processRecognizedSpeech();
        }
      }
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
    final language = _selectedLanguage.value;

    if (language == 'ko-KR' && _koreanChars.isNotEmpty) {
      _currentAlphabet.value = _koreanChars[_currentCharIndex[language]!];
      _currentCharIndex[language] = (_currentCharIndex[language]! + 1) % _koreanChars.length;
    } else if (language == 'ja-JP' && _japaneseChars.isNotEmpty) {
      _currentAlphabet.value = _japaneseChars[_currentCharIndex[language]!];
      _currentCharIndex[language] = (_currentCharIndex[language]! + 1) % _japaneseChars.length;
    } else {
      _currentAlphabet.value = "This is just for testing purpose";
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
      }
      // else if (_selectedPracticeMode.value == 'paragraphs') {
      //   mode = 'targeted';
      // }
      else {
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
      if (_selectedPracticeMode.value == 'alphabets') {
        try {
          final finalResult = await _speechService.getFinalResults();
          final finalText = finalResult['text']?.toString() ?? '';
          if (finalText.isNotEmpty) {
            _recognizedText.value = finalText;
            _processRecognizedSpeech();
          }
        } catch (e) {
          // Final result not available, continue with current recognized text
          if (kDebugMode) {
            print("Final result not available: $e");
          }
        }
      }
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