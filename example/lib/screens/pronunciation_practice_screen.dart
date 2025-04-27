import 'dart:math';
import 'package:flutter/material.dart';
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
  final List<String> _practiceModes = ['alphabets', 'paragraphs'];

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
    _generateNewAlphabet();
    _setupSpeechRecognition();
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
    _currentAlphabet.value = String.fromCharCode(Random().nextInt(26) + 65);
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