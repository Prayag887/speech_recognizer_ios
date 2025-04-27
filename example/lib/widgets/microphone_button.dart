import 'package:flutter/material.dart';

class MicrophoneButton extends StatelessWidget {
  final ValueNotifier<bool> isListening;
  final Function() onTapDown;
  final Function() onTapUp;
  final Function() onTapCancel;

  const MicrophoneButton({
    super.key,
    required this.isListening,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isListening,
      builder: (context, listening, _) {
        return GestureDetector(
          onTapDown: (_) => onTapDown(),
          onTapUp: (_) => onTapUp(),
          onTapCancel: onTapCancel,
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
}