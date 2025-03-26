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

    private let phoneticMappings: [String: [String]] = [
        "A": ["Hey", "Hay"],
        "B": ["Bee", "Be"],
        "C": ["Sea", "See"],
        "D": ["Dee"],
        "E": ["Ee"],
        "F": ["Apps", "App", "Have"],
        "G": ["Gee"],
        "H": ["At", "Add"],
        "I": ["Eye", "Hi", "High"], //075377
        "J": ["They"],
        "M": ["Am"],
        "N": ["And", "An"],
        "O": ["Oh"],
        "P": ["Pee", "Pea"],
        "R": ["Are"],
        "S": ["Yes", "As"],
        "T": ["Tea"],
        "U": ["You"],
        "X": ["Ex"],
        "Y": ["Why"],
    ]

    public static func register(with registrar: FlutterPluginRegistrar) {
        let eventChannel = FlutterEventChannel(
            name: "com.example.speech_recognizer/recognizer", 
            binaryMessenger: registrar.messenger()
        )
        let instance = SpeechRecognizationPlugin()
        eventChannel.setStreamHandler(instance)

        let methodChannel = FlutterMethodChannel(
            name: "com.example.speech_recognizer/methods", 
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startRecognition":
            if isRecognizing {
                result(FlutterError(code: "ALREADY_RECOGNIZING", message: "Recognition is already in progress", details: nil))
                return
            }

            if let arguments = call.arguments as? [String: Any],
               let languageCode = arguments["language"] as? String {
                let mode = arguments["mode"] as? String
                let targetText = arguments["targetText"] as? String
                startRecognition(languageCode: languageCode, mode: mode, targetText: targetText, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "No language code provided", details: nil))
            }
        case "stopRecognition":
            stopRecognition()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        if let languageCode = arguments as? String {
            startRecognition(languageCode: languageCode, result: { _ in })
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stopRecognition()
        return nil
    }

    private func startRecognition(languageCode: String, mode: String? = nil, targetText: String? = nil, result: @escaping FlutterResult) {
        isRecognizing = true
        
        print("Language Mode: \(mode ?? "nil")")
        print("Target Text: \(targetText ?? "nil")")

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self = self else { return }

            guard status == .authorized else {
                self.eventSink?("Speech recognition not authorized")
                result(FlutterError(code: "SPEECH_AUTHORIZATION", message: "Speech recognition not authorized", details: nil))
                self.isRecognizing = false
                return
            }

            let locale = Locale(identifier: languageCode)
            self.speechRecognizer = SFSpeechRecognizer(locale: locale)

            guard let recognizer = self.speechRecognizer, recognizer.isAvailable else {
                self.eventSink?("Language not supported or recognizer not available")
                result(FlutterError(code: "LANGUAGE_NOT_SUPPORTED", message: "Language not supported or recognizer not available", details: nil))
                self.isRecognizing = false
                return
            }

            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                self.eventSink?("Audio session error: \(error.localizedDescription)")
                result(FlutterError(code: "AUDIO_SESSION_ERROR", message: "Audio session error: \(error.localizedDescription)", details: nil))
                self.isRecognizing = false
                return
            }

            self.recognitionTask?.cancel()
            self.recognitionTask = nil
            self.recognitionRequest = nil

            self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

            guard let recognitionRequest = self.recognitionRequest else {
                self.eventSink?("Failed to create recognition request")
                result(FlutterError(code: "RECOGNITION_ERROR", message: "Failed to create recognition request", details: nil))
                self.isRecognizing = false
                return
            }

            let inputNode = self.audioEngine.inputNode
            inputNode.removeTap(onBus: 0)

            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }

            if !self.audioEngine.isRunning {
                self.audioEngine.prepare()
                do {
                    try self.audioEngine.start()
                } catch {
                    self.eventSink?("Audio Engine Error: \(error.localizedDescription)")
                    result(FlutterError(code: "AUDIO_ENGINE_ERROR", message: "Audio Engine Error: \(error.localizedDescription)", details: nil))
                    self.isRecognizing = false
                    return
                }
            }

            self.recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }

                if let result = result {
                    var recognizedText = result.bestTranscription.formattedString

                    // Apply phonetic correction
                    if let targetText = targetText, let phoneticVariants = self.phoneticMappings[targetText] {
                        if phoneticVariants.contains(where: { recognizedText.caseInsensitiveCompare($0) == .orderedSame }) {
                            recognizedText = targetText // Replace with target text
                        }
                    }

                    self.eventSink?(recognizedText)
                }

                if let error = error {
                    self.eventSink?("Error: \(error.localizedDescription)")
                    self.stopRecognition()
                }
            }
        }
    }

    private func stopRecognition() {
        if isRecognizing {
            audioEngine.inputNode.removeTap(onBus: 0)

            recognitionRequest?.endAudio()
            recognitionTask = nil
            recognitionRequest = nil

            isRecognizing = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.eventSink?("RECOGNITION_ENDED")
            }
        }
    }
}
