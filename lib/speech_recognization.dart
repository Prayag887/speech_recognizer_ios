import 'speech_recognization_platform_interface.dart';

class SpeechRecognization {
  Future<String?> getPlatformVersion() {
    return SpeechRecognizationPlatform.instance.getPlatformVersion();
  }
}
