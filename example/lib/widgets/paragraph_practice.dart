import 'package:flutter/material.dart';
import '../models/paragraph_data.dart';

class ParagraphPractice extends StatelessWidget {
  final ParagraphData paragraph;

  const ParagraphPractice({
    super.key,
    required this.paragraph,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(paragraph.text, style: const TextStyle(fontSize: 20, height: 1.4)),
          if (paragraph.translation.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text("Translation: ${paragraph.translation}"),
            ),
        ],
      ),
    );
  }
}