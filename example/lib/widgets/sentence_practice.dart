import 'package:flutter/material.dart';

class SentencePractice extends StatelessWidget {
  final ValueNotifier<String> currentSentence;
  final ValueNotifier<List<String>> spokenSentence;
  final ValueNotifier<String> confidence;

  const SentencePractice({
    super.key,
    required this.currentSentence,
    required this.spokenSentence,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Current Words", style: TextStyle(fontSize: 18)),
        ValueListenableBuilder<String>(
          valueListenable: currentSentence,
          builder: (context, char, _) => Text(char,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 20),
        ValueListenableBuilder<List<String>>(
          valueListenable: spokenSentence,
          builder: (context, spoken, _) => Text("Completed:\n${confidence.value}"),
        ),
      ],
    );
  }
}