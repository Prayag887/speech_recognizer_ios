import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IOS Speech',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const PronunciationPracticeScreen(),
    );
  }
}

class ParagraphData {
  final String text;
  final String translation;
  final String language;

  ParagraphData({
    required this.text,
    required this.translation,
    required this.language,
  });
}

class PronunciationPracticeScreen extends StatefulWidget {
  const PronunciationPracticeScreen({super.key});

  @override
  State<PronunciationPracticeScreen> createState() =>
      _PronunciationPracticeScreenState();
}

class _PronunciationPracticeScreenState
    extends State<PronunciationPracticeScreen> {
  static const EventChannel _eventChannel =
      EventChannel('com.example.speech_recognizer/recognizer');
  static const MethodChannel _methodChannel =
      MethodChannel('com.example.speech_recognizer/methods');

  final ValueNotifier<String> _recognizedText = ValueNotifier('');
  final ValueNotifier<String> _selectedLanguage = ValueNotifier('en-US');
  final ValueNotifier<bool> _isListening = ValueNotifier(false);
  final ValueNotifier<int> _selectedParagraphIndex = ValueNotifier(0);
  final ValueNotifier<String> _currentAlphabet = ValueNotifier('');
  final ValueNotifier<List<String>> _spokenAlphabets = ValueNotifier([]);

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

  final List<String> _languages = ['en-US', 'ja-JP', 'ko-KR', 'es-ES', 'fr-FR'];
  final List<String> _practiceModes = ['alphabets', 'paragraphs'];
  final ValueNotifier<String> _selectedPracticeMode =
      ValueNotifier('alphabets');

  @override
  void initState() {
    super.initState();
    _generateNewAlphabet();
    _setupSpeechRecognition();
  }

  void _setupSpeechRecognition() {
    _eventChannel.receiveBroadcastStream().listen((event) {
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

      await _methodChannel.invokeMethod('startRecognition', {
        'language': _selectedLanguage.value,
        'mode': mode,
        'targetText': _selectedPracticeMode.value == 'alphabets'
            ? _currentAlphabet.value
            : null,
      });
    } on PlatformException catch (e) {
      _recognizedText.value = "Error: ${e.message}";
      _isListening.value = false;
    }
  }

  Future<void> _stopListening() async {
    try {
      await _methodChannel.invokeMethod('stopRecognition');
      _isListening.value = false;
    } on PlatformException catch (e) {
      _recognizedText.value = "Error: ${e.message}";
      _isListening.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("IOS SPEECH RECOOGNIZER"),
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
            _buildLanguageSelector(),
            const SizedBox(height: 30),
            Expanded(child: _buildPracticeContent()),
            const SizedBox(height: 30),
            _buildMicrophoneButton(),
            const SizedBox(height: 20),
            _buildResultDisplay(),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return ValueListenableBuilder<String>(
      valueListenable: _selectedLanguage,
      builder: (context, lang, _) {
        return Wrap(
          spacing: 10,
          children: _languages
              .map((l) => FilterChip(
                    label: Text(_langName(l)),
                    selected: l == lang,
                    onSelected: _isListening.value
                        ? null
                        : (_) => _selectedLanguage.value = l,
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildPracticeContent() {
    return ValueListenableBuilder<String>(
      valueListenable: _selectedPracticeMode,
      builder: (context, mode, _) {
        if (mode == 'alphabets') {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Current Alphabet", style: TextStyle(fontSize: 18)),
              ValueListenableBuilder<String>(
                valueListenable: _currentAlphabet,
                builder: (context, char, _) => Text(char,
                    style: const TextStyle(
                        fontSize: 80, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<List<String>>(
                valueListenable: _spokenAlphabets,
                builder: (context, spoken, _) =>
                    Text("Completed: ${spoken.join(', ')}"),
              ),
            ],
          );
        }

        return SingleChildScrollView(
          child: Column(
            children: [
              Text(_paragraphs[_selectedParagraphIndex.value].text,
                  style: const TextStyle(fontSize: 20, height: 1.4)),
              if (_paragraphs[_selectedParagraphIndex.value]
                  .translation
                  .isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 20),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                      "Translation: ${_paragraphs[_selectedParagraphIndex.value].translation}"),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMicrophoneButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isListening,
      builder: (context, listening, _) {
        return GestureDetector(
          onTapDown: (_) => _startListening(),
          onTapUp: (_) => _stopListening(),
          onTapCancel: _stopListening,
          child: RawMaterialButton(
            onPressed: () {},
            fillColor:
                listening ? Colors.red : Theme.of(context).colorScheme.primary,
            elevation: 4,
            padding: const EdgeInsets.all(24),
            shape: const CircleBorder(),
            child: Icon(
              listening ? Icons.mic : Icons.mic_none,
              size: 36,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultDisplay() {
    return ValueListenableBuilder<String>(
      valueListenable: _recognizedText,
      builder: (context, text, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(15),
          ),
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Speech Result:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(text.isEmpty ? "Waiting for input..." : text),
            ],
          ),
        );
      },
    );
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
}

extension StringExtension on String {
  String capitalize() => "${this[0].toUpperCase()}${substring(1)}";
}
