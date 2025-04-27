import 'package:flutter/material.dart';

class LanguageSelector extends StatelessWidget {
  final List<String> languages;
  final ValueNotifier<String> selectedLanguage;
  final bool isListening;
  final String Function(String) langNameFn;

  const LanguageSelector({
    super.key,
    required this.languages,
    required this.selectedLanguage,
    required this.isListening,
    required this.langNameFn,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: selectedLanguage,
      builder: (context, lang, _) {
        return Wrap(
          spacing: 10,
          children: languages
              .map((l) => FilterChip(
            label: Text(langNameFn(l)),
            selected: l == lang,
            onSelected: isListening
                ? null
                : (_) => selectedLanguage.value = l,
          ))
              .toList(),
        );
      },
    );
  }
}