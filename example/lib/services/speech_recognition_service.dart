import 'package:flutter/services.dart';

class SpeechRecognitionService {
  static const EventChannel _eventChannel =
  EventChannel('com.example.speech_recognizer/recognizer');
  static const MethodChannel _methodChannel =
  MethodChannel('com.example.speech_recognizer/methods');

  Future<void> startRecognition({
    required String language,
    required String mode,
    String? targetText,
  }) async {
    try {
      await _methodChannel.invokeMethod('startRecognition', {
        'language': language,
        'mode': mode,
        'targetText': targetText,
      });
    } on PlatformException catch (e) {
      throw Exception("Error starting recognition: ${e.message}");
    }
  }

  Future<void> stopRecognition() async {
    try {
      await _methodChannel.invokeMethod('stopRecognition');
    } on PlatformException catch (e) {
      throw Exception("Error stopping recognition: ${e.message}");
    }
  }

  Stream<dynamic> get recognitionStream {
    return _eventChannel.receiveBroadcastStream();
  }
}