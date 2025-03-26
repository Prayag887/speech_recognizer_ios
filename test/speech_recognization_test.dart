import 'package:flutter_test/flutter_test.dart';
import 'package:speech_recognization/speech_recognization.dart';
import 'package:speech_recognization/speech_recognization_platform_interface.dart';
import 'package:speech_recognization/speech_recognization_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSpeechRecognizationPlatform
    with MockPlatformInterfaceMixin
    implements SpeechRecognizationPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final SpeechRecognizationPlatform initialPlatform = SpeechRecognizationPlatform.instance;

  test('$MethodChannelSpeechRecognization is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelSpeechRecognization>());
  });

  test('getPlatformVersion', () async {
    SpeechRecognization speechRecognizationPlugin = SpeechRecognization();
    MockSpeechRecognizationPlatform fakePlatform = MockSpeechRecognizationPlatform();
    SpeechRecognizationPlatform.instance = fakePlatform;

    expect(await speechRecognizationPlugin.getPlatformVersion(), '42');
  });
}
