import 'package:flutter/material.dart';

class AlphabetPractice extends StatelessWidget {
  final ValueNotifier<String> currentAlphabet;
  final ValueNotifier<List<String>> spokenAlphabets;

  const AlphabetPractice({
    super.key,
    required this.currentAlphabet,
    required this.spokenAlphabets,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Current Alphabet", style: TextStyle(fontSize: 18)),
        ValueListenableBuilder<String>(
          valueListenable: currentAlphabet,
          builder: (context, char, _) => Text(char,
              style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 20),
        ValueListenableBuilder<List<String>>(
          valueListenable: spokenAlphabets,
          builder: (context, spoken, _) => Text("Completed: ${spoken.join(', ')}"),
        ),
      ],
    );
  }
}