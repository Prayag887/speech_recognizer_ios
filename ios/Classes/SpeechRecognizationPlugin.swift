import AVFoundation
import Flutter
import Speech
import UIKit

public class SpeechRecognizationPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var isRecognizing = false
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var finalResult: [String: Any]?

    private let phoneticMappings: [String: [String]] = [
        "A": ["Hey", "Hay"], "B": ["Bee", "Be"], "C": ["Sea", "See"],
        "D": ["Dee"], "E": ["Ee"], "F": ["Apps", "App", "Have"],
        "G": ["Gee"], "H": ["At", "Add"], "I": ["Eye", "Hi", "High"],
        "J": ["They"], "M": ["Am"], "N": ["And", "An"], "O": ["Oh"],
        "P": ["Pee", "Pea"], "R": ["Are"], "S": ["Yes", "As"],
        "T": ["Tea"], "U": ["You"], "X": ["Ex"], "Y": ["Why"]
    ]

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SpeechRecognizationPlugin()
        let eventChannel = FlutterEventChannel(name: "com.example.speech_recognizer/recognizer", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)

        let methodChannel = FlutterMethodChannel(name: "com.example.speech_recognizer/methods", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startRecognition":
            guard !isRecognizing else {
                result(FlutterError(code: "ALREADY_RECOGNIZING", message: "Recognition already in progress", details: nil))
                return
            }

            guard let args = call.arguments as? [String: Any],
                  let languageCode = args["language"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Language code is required", details: nil))
                return
            }

            let mode = args["mode"] as? String
            let targetText = args["targetText"] as? String
            startRecognition(languageCode: languageCode, mode: mode, targetText: targetText, result: result)

        case "stopRecognition":
            stopRecognition()
            result(nil)

        case "getFinalResults":
            if var resultData = finalResult {
                if let args = call.arguments as? [String: Any],
                   let targetText = args["targetText"] as? String,
                   let originalText = resultData["originalText"] as? String,
                   let variants = phoneticMappings[targetText],
                   variants.contains(where: { originalText.caseInsensitiveCompare($0) == .orderedSame }) {
                    resultData["text"] = targetText
                }
                result(resultData)
            } else {
                result([
                    "text": "",
                    "originalText": "",
                    "isFinal": false,
                    "confidence": 0.0,
                    "timestamp": Date().timeIntervalSince1970,
                    "available": false
                ])
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stopRecognition()
        return nil
    }

    private func startRecognition(languageCode: String, mode: String?, targetText: String?, result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            self.isRecognizing = true
            self.finalResult = nil

            // Request both Speech Recognition and Microphone permissions
            self.requestPermissions { success, error in
                if !success {
                    let errorMessage = error ?? "Permission denied"
                    self.eventSink?([
                        "error": errorMessage,
                        "timestamp": Date().timeIntervalSince1970
                    ])
                    result(FlutterError(code: "PERMISSION_DENIED", message: errorMessage, details: nil))
                    self.isRecognizing = false
                    return
                }

                self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: languageCode))
                guard let recognizer = self.speechRecognizer, recognizer.isAvailable else {
                    let errorMessage = "Speech recognizer not available for language: \(languageCode)"
                    self.eventSink?([
                        "error": errorMessage,
                        "timestamp": Date().timeIntervalSince1970
                    ])
                    result(FlutterError(code: "RECOGNIZER_UNAVAILABLE", message: errorMessage, details: nil))
                    self.isRecognizing = false
                    return
                }

                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.record, mode: .measurement, options: .duckOthers)
                    try session.setActive(true, options: .notifyOthersOnDeactivation)
                } catch {
                    let errorMessage = "Audio session setup failed: \(error.localizedDescription)"
                    self.eventSink?([
                        "error": errorMessage,
                        "timestamp": Date().timeIntervalSince1970
                    ])
                    result(FlutterError(code: "AUDIO_SESSION", message: errorMessage, details: nil))
                    self.isRecognizing = false
                    return
                }

                self.recognitionRequest?.endAudio()
                self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
                self.recognitionRequest?.shouldReportPartialResults = true

                guard let request = self.recognitionRequest else {
                    let errorMessage = "Could not create speech recognition request"
                    self.eventSink?([
                        "error": errorMessage,
                        "timestamp": Date().timeIntervalSince1970
                    ])
                    result(FlutterError(code: "REQUEST_ERROR", message: errorMessage, details: nil))
                    self.isRecognizing = false
                    return
                }

                let node = self.audioEngine.inputNode
                node.removeTap(onBus: 0)
                node.installTap(onBus: 0, bufferSize: 1024, format: node.outputFormat(forBus: 0)) { buffer, _ in
                    request.append(buffer)
                }

                do {
                    self.audioEngine.prepare()
                    try self.audioEngine.start()
                } catch {
                    let errorMessage = "Audio engine failed to start: \(error.localizedDescription)"
                    self.eventSink?([
                        "error": errorMessage,
                        "timestamp": Date().timeIntervalSince1970
                    ])
                    result(FlutterError(code: "ENGINE_ERROR", message: errorMessage, details: nil))
                    self.isRecognizing = false
                    return
                }

                self.recognitionTask = recognizer.recognitionTask(with: request) { recognitionResult, error in
                    if let error = error {
                        self.eventSink?([
                            "error": error.localizedDescription,
                            "timestamp": Date().timeIntervalSince1970
                        ])
                        self.stopRecognition()
                        return
                    }

                    guard let result = recognitionResult else {
                        self.eventSink?([
                            "error": "No recognition result received.",
                            "timestamp": Date().timeIntervalSince1970
                        ])
                        return
                    }

                    let spoken = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                    if spoken.isEmpty {
                        self.eventSink?([
                            "error": "Please speak louder and clearly in a quiet environment.",
                            "timestamp": Date().timeIntervalSince1970
                        ])
                        return
                    }

                    var corrected = spoken
                    if let target = targetText,
                       let variants = self.phoneticMappings[target],
                       variants.contains(where: { spoken.caseInsensitiveCompare($0) == .orderedSame }) {
                        corrected = target
                    }

                    let confidence = result.bestTranscription.segments.first?.confidence ?? 0.0
                    let resultMap: [String: Any] = [
                        "text": corrected,
                        "originalText": spoken,
                        "isFinal": result.isFinal,
                        "confidence": confidence,
                        "timestamp": Date().timeIntervalSince1970
                    ]

                    if result.isFinal {
                        self.finalResult = resultMap
                        self.eventSink?(resultMap)
                        self.stopRecognition()
                    } else {
                        self.eventSink?(resultMap)
                    }
                }

                result(nil) // Recognition started successfully
            }
        }
    }

    private func requestPermissions(completion: @escaping (Bool, String?) -> Void) {
        // First check and request Speech Recognition permission
        let speechAuthStatus = SFSpeechRecognizer.authorizationStatus()

        switch speechAuthStatus {
        case .authorized:
            // Speech permission already granted, now check microphone
            self.requestMicrophonePermission(completion: completion)

        case .notDetermined:
            // Request speech recognition permission
            SFSpeechRecognizer.requestAuthorization { authStatus in
                DispatchQueue.main.async {
                    switch authStatus {
                    case .authorized:
                        self.requestMicrophonePermission(completion: completion)
                    case .denied:
                        completion(false, "Speech recognition permission denied. Please enable it in Settings.")
                    case .restricted:
                        completion(false, "Speech recognition is restricted on this device.")
                    case .notDetermined:
                        completion(false, "Speech recognition permission status is undetermined.")
                    @unknown default:
                        completion(false, "Unknown speech recognition permission status.")
                    }
                }
            }

        case .denied:
            completion(false, "Speech recognition permission denied. Please enable it in Settings.")

        case .restricted:
            completion(false, "Speech recognition is restricted on this device.")

        @unknown default:
            completion(false, "Unknown speech recognition permission status.")
        }
    }

    private func requestMicrophonePermission(completion: @escaping (Bool, String?) -> Void) {
        let audioSession = AVAudioSession.sharedInstance()
        let microphoneStatus = audioSession.recordPermission

        switch microphoneStatus {
        case .granted:
            completion(true, nil)

        case .denied:
            completion(false, "Microphone permission denied. Please enable it in Settings.")

        case .undetermined:
            audioSession.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        completion(true, nil)
                    } else {
                        completion(false, "Microphone permission denied. Please enable it in Settings.")
                    }
                }
            }

        @unknown default:
            completion(false, "Unknown microphone permission status.")
        }
    }

    private func stopRecognition() {
        if isRecognizing {
            audioEngine.inputNode.removeTap(onBus: 0)
            recognitionRequest?.endAudio()
            if audioEngine.isRunning {
                audioEngine.stop()
            }

            recognitionTask?.cancel()
            recognitionTask = nil
            recognitionRequest = nil
            isRecognizing = false
        }
    }
}