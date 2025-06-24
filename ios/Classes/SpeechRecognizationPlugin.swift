import AVFoundation
import Flutter
import Speech
import UIKit

public class SpeechRecognizationPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    
    // Store final result and latest result
    private var finalResult: [String: Any]?
    private var latestResult: [String: Any]?
    private var eventSink: FlutterEventSink?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var isRecognizing = false
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var manuallyStopped = false
    private var hasStartedRecognition = false

    // Phonetic threshold for matching (80%)
    private let phoneticThreshold: Double = 0.7

    private let phoneticMappings: [String: [String]] = [
        "A": ["Hey", "Hay"],
        "B": ["Bee", "Be"],
        "C": ["Sea", "See"],
        "D": ["Dee"],
        "E": ["Ee"],
        "F": ["Apps", "App", "Have"],
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
        "would": ["wood"],	
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
        case "getFinalResults":
            print("DEBUG - getFinalResults called")
            print("DEBUG - finalResult is nil: \(self.finalResult == nil)")
            print("DEBUG - latestResult is nil: \(self.latestResult == nil)")
            print("DEBUG - isRecognizing: \(self.isRecognizing)")
            print("DEBUG - hasStartedRecognition: \(self.hasStartedRecognition)")
            
            if let finalResult = self.finalResult {
                print("DEBUG - Returning final result")
                var resultWithStatus = finalResult
                resultWithStatus["available"] = true
                resultWithStatus["status"] = "completed"
                result(resultWithStatus)
            } else if let latestResult = self.latestResult {
                print("DEBUG - Returning latest result")
                var resultWithStatus = latestResult
                resultWithStatus["available"] = true
                resultWithStatus["status"] = isRecognizing ? "recognizing" : "partial"
                result(resultWithStatus)
            } else if isRecognizing {
                print("DEBUG - Recognition in progress")
                let progressResult: [String: Any] = [
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
                    "status": "recognizing"
                ]
                result(progressResult)
            } else {
                print("DEBUG - Returning empty result")
                let emptyResult: [String: Any] = [
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
                ]
                result(emptyResult)
            }
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
        hasStartedRecognition = true
        // Don't clear results immediately - only clear when we get new data
        
        print("Language Mode: \(mode ?? "nil")")
        print("Target Text: \(targetText ?? "nil")")

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let strongSelf = self else { return }

            guard status == .authorized else {
                strongSelf.eventSink?("Speech recognition not authorized")
                result(FlutterError(code: "SPEECH_AUTHORIZATION", message: "Speech recognition not authorized", details: nil))
                strongSelf.isRecognizing = false
                return
            }

            let locale = Locale(identifier: languageCode)
            strongSelf.speechRecognizer = SFSpeechRecognizer(locale: locale)

            guard let recognizer = strongSelf.speechRecognizer, recognizer.isAvailable else {
                strongSelf.eventSink?("Language not supported or recognizer not available")
                result(FlutterError(code: "LANGUAGE_NOT_SUPPORTED", message: "Language not supported or recognizer not available", details: nil))
                strongSelf.isRecognizing = false
                return
            }

            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                strongSelf.eventSink?("Audio session error: \(error.localizedDescription)")
                result(FlutterError(code: "AUDIO_SESSION_ERROR", message: "Audio session error: \(error.localizedDescription)", details: nil))
                strongSelf.isRecognizing = false
                return
            }

            strongSelf.recognitionTask?.cancel()
            strongSelf.recognitionTask = nil
            strongSelf.recognitionRequest = nil
            strongSelf.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

            guard let recognitionRequest = strongSelf.recognitionRequest else {
                strongSelf.eventSink?("Failed to create recognition request")
                result(FlutterError(code: "RECOGNITION_ERROR", message: "Failed to create recognition request", details: nil))
                strongSelf.isRecognizing = false
                return
            }

            let inputNode = strongSelf.audioEngine.inputNode
            inputNode.removeTap(onBus: 0)

            let recordingFormat = inputNode.inputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }

            if !strongSelf.audioEngine.isRunning {
                strongSelf.audioEngine.prepare()
                do {
                    try strongSelf.audioEngine.start()
                } catch {
                    strongSelf.eventSink?("Audio Engine Error: \(error.localizedDescription)")
                    result(FlutterError(code: "AUDIO_ENGINE_ERROR", message: "Audio Engine Error: \(error.localizedDescription)", details: nil))
                    strongSelf.isRecognizing = false
                    return
                }
            }

            strongSelf.recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let strongSelf = self else { return }

                if let result = result {
                    let recognizedText = result.bestTranscription.formattedString
                    let originalConfidence = result.bestTranscription.segments.first?.confidence ?? 0.0

                    if recognizedText.isEmpty {
                        strongSelf.eventSink?("Please speak loudly and clearly in silent environment")
                        return
                    }

                    var finalText = recognizedText
                    var phoneticAccuracy = Double(originalConfidence)
                    var levenshteinSimilarity = 0.0
                    var soundexSimilarity = 0.0
                    var matched = false

                    // First check legacy phonetic mappings
                    if let targetText = targetText, let phoneticVariants = strongSelf.phoneticMappings[targetText] {
                        if phoneticVariants.contains(where: { recognizedText.caseInsensitiveCompare($0) == .orderedSame }) {
                            finalText = targetText
                            matched = true
                            phoneticAccuracy = 1.0
                            levenshteinSimilarity = 1.0
                            soundexSimilarity = 1.0
                        }
                    }

                    // If no legacy match found and we have a target text, use advanced phonetic analysis
                    if !matched, let targetText = targetText {
                        let analysisResult = PhoneticAnalyzer.analyzeMultipleWords(
                            recognizedText: recognizedText,
                            targetText: targetText,
                            originalConfidence: Double(originalConfidence),
                            threshold: strongSelf.phoneticThreshold
                        )
                        print("target text:: $\(targetText), recognized text:: $\(recognizedText)")

                        finalText = analysisResult.finalText
                        phoneticAccuracy = analysisResult.phoneticAccuracy
                        levenshteinSimilarity = analysisResult.levenshteinSimilarity
                        soundexSimilarity = analysisResult.soundexSimilarity
                        matched = analysisResult.matched
                    }

                    // Calculate final confidence based on phonetic accuracy
                    let finalConfidence = matched ? phoneticAccuracy : Double(originalConfidence)

                    let resultData: [String: Any] = [
                        "text": finalText,
                        "originalText": recognizedText,
                        "isFinal": result.isFinal,
                        "confidence": finalConfidence,
                        "phoneticAccuracy": phoneticAccuracy,
                        "levenshteinSimilarity": levenshteinSimilarity,
                        "soundexSimilarity": soundexSimilarity,
                        "matched": matched,
                        "timestamp": Date().timeIntervalSince1970
                    ]

                    // Always store the latest result
                    strongSelf.latestResult = resultData
                    
                    if result.isFinal {
                        // Store as final result
                        strongSelf.finalResult = resultData
                        strongSelf.eventSink?(resultData)

                        // Cleanup
                        strongSelf.audioEngine.stop()
                        strongSelf.audioEngine.inputNode.removeTap(onBus: 0)
                        strongSelf.recognitionRequest?.endAudio()
                        strongSelf.recognitionTask?.cancel()
                        strongSelf.recognitionTask = nil
                        strongSelf.recognitionRequest = nil
                        strongSelf.isRecognizing = false
                        
                        print("DEBUG - Final result stored: \(resultData)")
                    }

                    strongSelf.eventSink?(resultData)
                }

                if let error = error {
                    guard let strongSelf = self else { return }
                    let errorData: [String: Any] = [
                        "error": error.localizedDescription,
                        "timestamp": Date().timeIntervalSince1970
                    ]
                    strongSelf.eventSink?(errorData)
                    strongSelf.stopRecognition()
                }
            }
        }
    }

    private func stopRecognition() {
        if isRecognizing {
            manuallyStopped = true

            if finalResult == nil && latestResult != nil {
                var finalData = latestResult!
                finalData["isFinal"] = true
                finalData["stoppedManually"] = true
                finalResult = finalData
            }

            // Clean up audio engine first
            audioEngine.inputNode.removeTap(onBus: 0)
            recognitionRequest?.endAudio()

            if audioEngine.isRunning {
                audioEngine.stop()
                audioEngine.reset()
            }

            // Reset audio session category for playback
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("Failed to reset audio session: \(error)")
            }

            isRecognizing = false
        }
    }
}
