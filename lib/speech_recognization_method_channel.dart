import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'speech_recognization_platform_interface.dart';

/// An implementation of [SpeechRecognizationPlatform] that uses method channels.
class MethodChannelSpeechRecognization extends SpeechRecognizationPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('speech_recognization');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
