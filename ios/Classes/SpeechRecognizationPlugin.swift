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
    private var targetText: String?

    // Enhanced phonetic threshold for matching
    private let phoneticThreshold: Double = 0.70 // Slightly lower for better fast speech detection
    private let contextualThreshold: Double = 0.65 // Even lower when using context

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
        self.targetText = targetText // Store target text for context

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

            // Enhanced audio session configuration for better fast speech recognition
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetooth])
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

                // Set preferred sample rate and buffer duration for better quality
                try audioSession.setPreferredSampleRate(44100.0)
                try audioSession.setPreferredIOBufferDuration(0.005) // 5ms for lower latency
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

            // Enhanced recognition request configuration
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.requiresOnDeviceRecognition = false // Use server-based for better accuracy

            // Add context hint if target text is provided
            if let targetText = targetText {
                // Create contextual phrases to help recognition
                let contextualPhrases = strongSelf.generateContextualPhrases(from: targetText)
                recognitionRequest.contextualStrings = contextualPhrases
            }

            let inputNode = strongSelf.audioEngine.inputNode
            inputNode.removeTap(onBus: 0)

            // Enhanced audio processing with higher quality settings
            let hwFormat = inputNode.outputFormat(forBus: 0)
            let desiredFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                              sampleRate: 44100.0,
                                              channels: 1,
                                              interleaved: false)!

            let converter = AVAudioConverter(from: hwFormat, to: desiredFormat)!

            inputNode.installTap(onBus: 0, bufferSize: 512, format: hwFormat) { buffer, _ in
                let convertedBuffer = AVAudioPCMBuffer(pcmFormat: desiredFormat,
                                                       frameCapacity: AVAudioFrameCount(desiredFormat.sampleRate * 0.1))!
                var error: NSError?
                converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
                recognitionRequest.append(convertedBuffer)
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

                    // Enhanced text processing with multiple candidate analysis
                    let processedResult = strongSelf.processRecognitionResult(
                        recognizedText: recognizedText,
                        originalConfidence: Double(originalConfidence),
                        targetText: targetText,
                        allTranscriptions: result.transcriptions
                    )

                    let resultData: [String: Any] = [
                        "text": processedResult.finalText,
                        "originalText": recognizedText,
                        "isFinal": result.isFinal,
                        "confidence": processedResult.finalConfidence,
                        "phoneticAccuracy": processedResult.phoneticAccuracy,
                        "levenshteinSimilarity": processedResult.levenshteinSimilarity,
                        "soundexSimilarity": processedResult.soundexSimilarity,
                        "matched": processedResult.matched,
                        "timestamp": Date().timeIntervalSince1970,
                        "candidatesAnalyzed": processedResult.candidatesAnalyzed,
                        "bestCandidateIndex": processedResult.bestCandidateIndex
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

    // MARK: - Enhanced Recognition Processing

    private func processRecognitionResult(
        recognizedText: String,
        originalConfidence: Double,
        targetText: String?,
        allTranscriptions: [SFTranscription]
    ) -> (finalText: String, finalConfidence: Double, phoneticAccuracy: Double, levenshteinSimilarity: Double, soundexSimilarity: Double, matched: Bool, candidatesAnalyzed: Int, bestCandidateIndex: Int) {

        var finalText = recognizedText
        var phoneticAccuracy = originalConfidence
        var levenshteinSimilarity = 0.0
        var soundexSimilarity = 0.0
        var matched = false
        var candidatesAnalyzed = 0
        var bestCandidateIndex = 0

        guard let targetText = targetText else {
            return (finalText, originalConfidence, phoneticAccuracy, levenshteinSimilarity, soundexSimilarity, matched, candidatesAnalyzed, bestCandidateIndex)
        }

        // Analyze multiple transcription candidates
        var bestMatch: (text: String, score: Double, accuracy: Double, levenshtein: Double, soundex: Double, matched: Bool) = (recognizedText, originalConfidence, originalConfidence, 0.0, 0.0, false)

        candidatesAnalyzed = min(allTranscriptions.count, 5) // Analyze top 5 candidates

        for (index, transcription) in allTranscriptions.prefix(5).enumerated() {
            let candidateText = transcription.formattedString
            let candidateConfidence = transcription.segments.first?.confidence ?? 0.0

            // First check legacy phonetic mappings
            var candidateMatched = false
            var candidateFinalText = candidateText
            var candidatePhoneticAccuracy = Double(candidateConfidence)
            var candidateLevenshtein = 0.0
            var candidateSoundex = 0.0

            if let phoneticVariants = phoneticMappings[targetText] {
                if phoneticVariants.contains(where: { candidateText.caseInsensitiveCompare($0) == .orderedSame }) {
                    candidateFinalText = targetText
                    candidateMatched = true
                    candidatePhoneticAccuracy = 1.0
                    candidateLevenshtein = 1.0
                    candidateSoundex = 1.0
                }
            }

            // If no legacy match found, use advanced phonetic analysis
            if !candidateMatched {
                let analysisResult = PhoneticAnalyzer.analyzeMultipleWords(
                    recognizedText: candidateText,
                    targetText: targetText,
                    originalConfidence: Double(candidateConfidence),
                    threshold: contextualThreshold // Use lower threshold when we have context
                )

                candidateFinalText = analysisResult.finalText
                candidatePhoneticAccuracy = analysisResult.phoneticAccuracy
                candidateLevenshtein = analysisResult.levenshteinSimilarity
                candidateSoundex = analysisResult.soundexSimilarity
                candidateMatched = analysisResult.matched
            }

            // Calculate composite score considering confidence, phonetic accuracy, and context
            let contextBoost = candidateMatched ? 0.3 : 0.0
            let compositeScore = (candidatePhoneticAccuracy * 0.4) +
                               (candidateLevenshtein * 0.3) +
                               (candidateSoundex * 0.2) +
                               (Double(candidateConfidence) * 0.1) +
                               contextBoost

            if compositeScore > bestMatch.score || (candidateMatched && !bestMatch.matched) {
                bestMatch = (candidateFinalText, compositeScore, candidatePhoneticAccuracy, candidateLevenshtein, candidateSoundex, candidateMatched)
                bestCandidateIndex = index
            }
        }

        finalText = bestMatch.text
        phoneticAccuracy = bestMatch.accuracy
        levenshteinSimilarity = bestMatch.levenshtein
        soundexSimilarity = bestMatch.soundex
        matched = bestMatch.matched

        // Calculate final confidence
        let finalConfidence = matched ? phoneticAccuracy : originalConfidence

        return (finalText, finalConfidence, phoneticAccuracy, levenshteinSimilarity, soundexSimilarity, matched, candidatesAnalyzed, bestCandidateIndex)
    }

    private func generateContextualPhrases(from targetText: String) -> [String] {
        var phrases = [targetText]

        // Add common variations and phonetic alternatives
        let words = targetText.lowercased().components(separatedBy: .whitespaces)

        // Add individual words as context
        phrases.append(contentsOf: words)

        // Add common phonetic variations
        for word in words {
            if let variants = phoneticMappings[word] {
                phrases.append(contentsOf: variants)
            }

            // Add common mispronunciations or similar sounding words
            switch word {
            case "james":
                phrases.append(contentsOf: ["jams", "gems", "jims", "jane's"])
            case "shopkeeper":
                phrases.append(contentsOf: ["shop keeper", "shopkeepr", "shop kipper"])
            case "is":
                phrases.append(contentsOf: ["his", "as", "was"])
            case "a":
                phrases.append(contentsOf: ["the", "an", "ay"])
            default:
                break
            }
        }

        return Array(Set(phrases)) // Remove duplicates
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
            targetText = nil
        }
    }
}
