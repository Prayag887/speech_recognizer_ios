import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';


class SpeechRecognizerIos {
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
      await Future.delayed(Duration(seconds: 2));
      await _methodChannel.invokeMethod('stopRecognition');
    } on PlatformException catch (e) {
      throw Exception("Error stopping recognition: ${e.message}");
    }
  }

  Stream<dynamic> get recognitionStream {
    print("Stream started");
    return _eventChannel.receiveBroadcastStream().distinct();
  }

  Future<Map<String, dynamic>> getFinalResults() async {
    try {
      final result = await _methodChannel.invokeMethod('getFinalResults');
      await Future.delayed(Duration(seconds: 2));

      if (kDebugMode) {
        print("Final result: $result");
      }
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw Exception("Error getting final results: ${e.message}");
    }
  }
}
