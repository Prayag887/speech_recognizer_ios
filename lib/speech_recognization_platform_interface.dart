import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'speech_recognization_method_channel.dart';

abstract class SpeechRecognizationPlatform extends PlatformInterface {
  /// Constructs a SpeechRecognizationPlatform.
  SpeechRecognizationPlatform() : super(token: _token);

  static final Object _token = Object();

  static SpeechRecognizationPlatform _instance = MethodChannelSpeechRecognization();

  /// The default instance of [SpeechRecognizationPlatform] to use.
  ///
  /// Defaults to [MethodChannelSpeechRecognization].
  static SpeechRecognizationPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [SpeechRecognizationPlatform] when
  /// they register themselves.
  static set instance(SpeechRecognizationPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
