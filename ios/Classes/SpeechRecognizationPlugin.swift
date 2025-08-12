import AVFoundation
import Flutter
import Speech
import UIKit

@available(iOS 13, *)
public class SpeechRecognizationPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    // MARK: - Public plugin properties
    private var eventSink: FlutterEventSink?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var audioEngine = AVAudioEngine()

    private(set) var isRecognizing = false
    private var hasStartedRecognition = false
    private var manuallyStopped = false

    // Results
    private var latestResult: [String: Any]?
    private var finalResult: [String: Any]?

    // Phonetic/thresholds
    private let phoneticThreshold: Double = 0.70
    private var enableAutomaticGainControl = true

    // Optional legacy phonetic mappings (you had these earlier)
    private let phoneticMappings: [String: [String]] = [
        "A": ["Hey", "Hay"],
        "B": ["Bee", "Be"],
        "C": ["Sea", "See"],
        "D": ["Dee"],
        "E": ["Ee"],
        "F": ["Apps", "App", "Have", "Yeah", "Yup", "Yes"],
        "G": ["Gee"],
        "H": ["At", "Add"],
        "I": ["Eye", "Hi", "High"],
        "J": ["They"],
        "M": ["Am"],
        "N": ["And", "An"],
        "O": ["Oh"],
        "P": ["Pee", "Pea"],
        "Q": ["Queue"],
        "R": ["Are"],
        "S": ["Yes", "As", "Ace"],
        "T": ["Tea"],
        "U": ["You"],
        "X": ["Ex"],
        "Y": ["Why"],
        "coat": ["\"", "court", "quote"],
        "court": ["\"", "coat", "quote"],
        "wood": ["would"],
        "would": ["wood"]
    ]

    // MARK: - Plugin registration
    public static func register(with registrar: FlutterPluginRegistrar) {
        let eventChannel = FlutterEventChannel(name: "com.example.speech_recognizer/recognizer",
                                               binaryMessenger: registrar.messenger())
        let instance = SpeechRecognizationPlugin()
        eventChannel.setStreamHandler(instance)

        let methodChannel = FlutterMethodChannel(name: "com.example.speech_recognizer/methods",
                                                 binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
    }

    // MARK: - FlutterMethodCall handler
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startRecognition":
            if isRecognizing {
                result(FlutterError(code: "ALREADY_RECOGNIZING", message: "Recognition in progress", details: nil))
                return
            }
            guard let args = call.arguments as? [String: Any],
                  let languageCode = args["language"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "language param required", details: nil))
                return
            }
            let mode = args["mode"] as? String
            let targetText = args["targetText"] as? String
            startRecognition(languageCode: languageCode, mode: mode, targetText: targetText, result: result)
        case "stopRecognition":
            stopRecognition()
            result(nil)
        case "getFinalResults":
            // Simplified getter for your app
            if let final = finalResult {
                var r = final
                r["available"] = true
                r["status"] = "completed"
                result(r)
            } else if let latest = latestResult {
                var r = latest
                r["available"] = true
                r["status"] = isRecognizing ? "recognizing" : "partial"
                result(r)
            } else {
                result([
                    "text": "",
                    "originalText": "",
                    "isFinal": false,
                    "confidence": 0.0,
                    "phoneticAccuracy": 0.0,
                    "levenshteinSimilarity": 0.0,
                    "soundexSimilarity": 0.0,
                    "matched": false,
                    "timestamp": Date().timeIntervalSince1970,
                    "available": false,
                    "status": hasStartedRecognition ? "stopped" : "not_started"
                ])
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - EventChannel
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stopRecognition()
        self.eventSink = nil
        return nil
    }

    // MARK: - Start recognition (full implementation)
    private func startRecognition(languageCode: String,
                                  mode: String? = nil,
                                  targetText: String? = nil,
                                  result: @escaping FlutterResult) {
        isRecognizing = true
        hasStartedRecognition = true
        manuallyStopped = false

        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            guard let self = self else { return }
            guard authStatus == .authorized else {
                self.eventSink?(["error": "Speech not authorized"])
                result(FlutterError(code: "SPEECH_AUTHORIZATION", message: "Speech not authorized", details: nil))
                self.isRecognizing = false
                return
            }

            let locale = Locale(identifier: languageCode)
            self.speechRecognizer = SFSpeechRecognizer(locale: locale)

            guard let recognizer = self.speechRecognizer, recognizer.isAvailable else {
                result(FlutterError(code: "LANG_NOT_AVAIL", message: "Language not available", details: nil))
                self.isRecognizing = false
                return
            }

            // Configure audio session safely (use rawValue for voiceRecognition to avoid compile-time missing enum case)
            let audioSession = AVAudioSession.sharedInstance()
            let desiredMode = AVAudioSession.Mode(rawValue: "voiceRecognition") // safe across SDKs
            do {
                try audioSession.setCategory(.record, mode: desiredMode, options: .duckOthers)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                // low IO buffer helps responsiveness
                try audioSession.setPreferredIOBufferDuration(0.005)
            } catch {
                // fallback to measurement
                do {
                    try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
                    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                } catch {
                    result(FlutterError(code: "AUDIO_SESSION_ERROR", message: "Audio Session setup failed: \(error.localizedDescription)", details: nil))
                    self.isRecognizing = false
                    return
                }
            }

            // Reset previous tasks / requests
            self.recognitionTask?.cancel()
            self.recognitionTask = nil
            self.recognitionRequest = nil

            // Setup request
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = false
            if let tt = targetText {
                request.contextualStrings = [tt] // CORRECT assignment
            }
            self.recognitionRequest = request

            // Input node tap: append buffers (with optional AGC/normalization)
            let inputNode = self.audioEngine.inputNode
            inputNode.removeTap(onBus: 0)
            let recordingFormat = inputNode.inputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, when in
                guard let self = self else { return }
                if self.enableAutomaticGainControl {
                    self.normalizeBufferInPlace(buffer: buffer)
                }
                request.append(buffer)
            }

            // Start engine immediately (so lead-in audio isn't clipped)
            self.audioEngine.prepare()
            do {
                try self.audioEngine.start()
            } catch {
                result(FlutterError(code: "AUDIO_ENGINE_ERROR", message: "Failed to start audio engine: \(error.localizedDescription)", details: nil))
                self.isRecognizing = false
                return
            }

            // Give the engine a tiny moment (200-300ms) to stabilize before creating the recognition task
            let delay = DispatchTime.now() + 0.25
            DispatchQueue.global().asyncAfter(deadline: delay) {
                self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] recogResult, error in
                    guard let self = self else { return }

                    if let recogResult = recogResult {
                        let recognizedText = recogResult.bestTranscription.formattedString
                        let originalConfidence = recogResult.bestTranscription.segments.first?.confidence ?? 0.0

                        // if empty / very low input -> warn
                        if recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            self.eventSink?(["warning": "Please speak clearly"])
                            return
                        }

                        // Check legacy mapping first
                        var finalText = recognizedText
                        var phoneticAccuracy = Double(originalConfidence)
                        var levenshteinSimilarity = 0.0
                        var soundexSimilarity = 0.0
                        var matched = false

                        if let targetText = targetText,
                           let phoneticVariants = self.phoneticMappings[targetText] {
                            if phoneticVariants.contains(where: { recognizedText.caseInsensitiveCompare($0) == .orderedSame }) {
                                finalText = targetText
                                matched = true
                                phoneticAccuracy = 1.0
                                levenshteinSimilarity = 1.0
                                soundexSimilarity = 1.0
                            }
                        }

                        // If not matched via legacy mapping -> run the analyzer
                        if !matched, let targetText = targetText {
                            let analysis = PhoneticAnalyzer.analyzeMultipleWords(recognizedText: recognizedText,
                                                                                 targetText: targetText,
                                                                                 originalConfidence: Double(originalConfidence),
                                                                                 threshold: self.phoneticThreshold)
                            finalText = analysis.finalText
                            phoneticAccuracy = analysis.phoneticAccuracy
                            levenshteinSimilarity = analysis.levenshteinSimilarity
                            soundexSimilarity = analysis.soundexSimilarity
                            matched = analysis.matched
                        }

                        // finalConfidence: if matched, prefer phoneticAccuracy, else originalConfidence
                        let finalConfidence = matched ? phoneticAccuracy : Double(originalConfidence)

                        let resultData: [String: Any] = [
                            "text": finalText,
                            "originalText": recognizedText,
                            "isFinal": recogResult.isFinal,
                            "confidence": finalConfidence,
                            "phoneticAccuracy": phoneticAccuracy,
                            "levenshteinSimilarity": levenshteinSimilarity,
                            "soundexSimilarity": soundexSimilarity,
                            "matched": matched,
                            "timestamp": Date().timeIntervalSince1970
                        ]

                        self.latestResult = resultData
                        self.eventSink?(resultData)

                        if recogResult.isFinal {
                            self.finalResult = resultData
                            // cleanup
                            self.cleanupAudioAndTasks()
                        }
                    }

                    if let err = error {
                        self.eventSink?(["error": err.localizedDescription, "timestamp": Date().timeIntervalSince1970])
                        self.cleanupAudioAndTasks()
                    }
                }
            } // end delay
        } // end requestAuthorization
    }

    // MARK: - Stop / Cleanup
    private func stopRecognition() {
        if !isRecognizing { return }
        manuallyStopped = true

        // If we have no finalResult but have latest -> promote it
        if finalResult == nil, let latest = latestResult {
            var promoted = latest
            promoted["isFinal"] = true
            promoted["stoppedManually"] = true
            finalResult = promoted
        }

        cleanupAudioAndTasks()
    }

    private func cleanupAudioAndTasks() {
        // remove tap safely
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.reset()
        }

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecognizing = false

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // ignore errors here
        }
    }

    // MARK: - Automatic gain control (in-place buffer normalization)
    // Simple RMS-based normalization to boost low-volume speech (only for PCM Float32)
    private func normalizeBufferInPlace(buffer: AVAudioPCMBuffer) {
        guard let floatData = buffer.floatChannelData else { return }
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        // compute RMS
        var sumSquares: Float = 0.0
        for ch in 0..<channelCount {
            let channel = floatData[ch]
            for i in 0..<frameLength {
                let s = channel[i]
                sumSquares += s * s
            }
        }
        let meanSquare = sumSquares / Float(frameLength * channelCount)
        let rms = sqrt(meanSquare)

        // target RMS and gain clamp
        let targetRMS: Float = 0.03 // tweakable
        if rms < 0.0005 {
            // too quiet; no reliable signal -> skip (avoid extreme gain)
            return
        }
        var gain = targetRMS / rms
        if gain < 1.0 { return } // only amplify, don't reduce
        if gain > 12.0 { gain = 12.0 } // clamp

        for ch in 0..<channelCount {
            let channel = floatData[ch]
            for i in 0..<frameLength {
                channel[i] = channel[i] * gain
            }
        }
    }
}
