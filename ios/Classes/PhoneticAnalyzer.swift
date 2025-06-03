import Foundation

public class PhoneticAnalyzer {

    public struct AnalysisResult {
        let finalText: String
        let originalText: String
        let phoneticAccuracy: Double
        let levenshteinSimilarity: Double
        let soundexSimilarity: Double
        let overallConfidence: Double
        let matched: Bool
    }

    public static func analyzePhoneticMatch(
        recognizedText: String,
        targetText: String,
        originalConfidence: Double = 0.0,
        threshold: Double = 0.8
    ) -> AnalysisResult {

        // Clean and normalize texts
        let cleanRecognized = cleanText(recognizedText)
        let cleanTarget = cleanText(targetText)

        // Calculate Levenshtein similarity
        let levenshteinSim = LevenshteinDistance.similarity(cleanRecognized, cleanTarget)

        // Calculate Soundex similarity
        let soundexSim = SoundexAlgorithm.phoneticSimilarity(cleanRecognized, cleanTarget)

        // Calculate combined phonetic accuracy
        let phoneticAccuracy = (levenshteinSim * 0.6) + (soundexSim * 0.4)

        // Determine if match meets threshold
        let isMatch = phoneticAccuracy >= threshold

        // Calculate overall confidence
        let overallConfidence = calculateOverallConfidence(
            phoneticAccuracy: phoneticAccuracy,
            originalConfidence: originalConfidence,
            isMatch: isMatch
        )

        // Determine final text
        let finalText = isMatch ? targetText : recognizedText

        return AnalysisResult(
            finalText: finalText,
            originalText: recognizedText,
            phoneticAccuracy: phoneticAccuracy,
            levenshteinSimilarity: levenshteinSim,
            soundexSimilarity: soundexSim,
            overallConfidence: overallConfidence,
            matched: isMatch
        )
    }

    public static func analyzeMultipleWords(
        recognizedText: String,
        targetText: String,
        originalConfidence: Double = 0.0,
        threshold: Double = 0.8
    ) -> AnalysisResult {

        let recognizedWords = recognizedText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let targetWords = targetText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        // If single words, use simple analysis
        if recognizedWords.count == 1 && targetWords.count == 1 {
            return analyzePhoneticMatch(
                recognizedText: recognizedText,
                targetText: targetText,
                originalConfidence: originalConfidence,
                threshold: threshold
            )
        }

        // For multiple words, analyze word by word and take average
        var totalPhoneticAccuracy = 0.0
        var totalLevenshtein = 0.0
        var totalSoundex = 0.0
        var matchedWords = 0

        let maxCount = max(recognizedWords.count, targetWords.count)

        for i in 0..<maxCount {
            let recognizedWord = i < recognizedWords.count ? recognizedWords[i] : ""
            let targetWord = i < targetWords.count ? targetWords[i] : ""

            if !recognizedWord.isEmpty && !targetWord.isEmpty {
                let wordResult = analyzePhoneticMatch(
                    recognizedText: recognizedWord,
                    targetText: targetWord,
                    originalConfidence: originalConfidence,
                    threshold: threshold
                )

                totalPhoneticAccuracy += wordResult.phoneticAccuracy
                totalLevenshtein += wordResult.levenshteinSimilarity
                totalSoundex += wordResult.soundexSimilarity

                if wordResult.matched {
                    matchedWords += 1
                }
            }
        }

        let wordCount = max(recognizedWords.count, targetWords.count, 1)
        let avgPhoneticAccuracy = totalPhoneticAccuracy / Double(wordCount)
        let avgLevenshtein = totalLevenshtein / Double(wordCount)
        let avgSoundex = totalSoundex / Double(wordCount)

        let isMatch = avgPhoneticAccuracy >= threshold
        let overallConfidence = calculateOverallConfidence(
            phoneticAccuracy: avgPhoneticAccuracy,
            originalConfidence: originalConfidence,
            isMatch: isMatch
        )

        let finalText = isMatch ? targetText : recognizedText

        return AnalysisResult(
            finalText: finalText,
            originalText: recognizedText,
            phoneticAccuracy: avgPhoneticAccuracy,
            levenshteinSimilarity: avgLevenshtein,
            soundexSimilarity: avgSoundex,
            overallConfidence: overallConfidence,
            matched: isMatch
        )
    }

    private static func cleanText(_ text: String) -> String {
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "[^a-zA-Z0-9\\s]", with: "", options: .regularExpression)
    }

    private static func calculateOverallConfidence(
        phoneticAccuracy: Double,
        originalConfidence: Double,
        isMatch: Bool
    ) -> Double {
        let baseConfidence = phoneticAccuracy * 0.7 + originalConfidence * 0.3

        // Boost confidence if it's a match
        if isMatch {
            return min(1.0, baseConfidence * 1.1)
        }

        return baseConfidence
    }
}