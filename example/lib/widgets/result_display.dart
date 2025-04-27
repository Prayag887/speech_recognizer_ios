import 'package:flutter/material.dart';

class ResultDisplay extends StatelessWidget {
  final ValueNotifier<String> recognizedText;

  const ResultDisplay({
    super.key,
    required this.recognizedText,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: recognizedText,
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
}