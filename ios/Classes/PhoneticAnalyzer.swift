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

    // Dynamic thresholds for different matching scenarios
    private static let strictThreshold: Double = 0.8
    private static let moderateThreshold: Double = 0.7
    private static let lenientThreshold: Double = 0.6

    public static func analyzePhoneticMatch(
        recognizedText: String,
        targetText: String,
        originalConfidence: Double = 0.0,
        threshold: Double = 0.8
    ) -> AnalysisResult {

        // Clean and normalize texts
        let cleanRecognized = cleanText(recognizedText)
        let cleanTarget = cleanText(targetText)

        // Calculate multiple similarity metrics
        let levenshteinSim = calculateLevenshteinSimilarity(cleanRecognized, cleanTarget)
        let soundexSim = calculateSoundexSimilarity(cleanRecognized, cleanTarget)
        let phoneticFeatureSim = calculatePhoneticFeaturesSimilarity(cleanRecognized, cleanTarget)
        let structuralSim = calculateStructuralSimilarity(cleanRecognized, cleanTarget)

        // Calculate weighted phonetic accuracy
        let phoneticAccuracy = (levenshteinSim * 0.3) +
                              (soundexSim * 0.25) +
                              (phoneticFeatureSim * 0.3) +
                              (structuralSim * 0.15)

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

        print("PhoneticAnalyzer DEBUG - '\(cleanRecognized)' vs '\(cleanTarget)': accuracy=\(phoneticAccuracy), match=\(isMatch)")

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

        print("PhoneticAnalyzer DEBUG - Analyzing words: \(recognizedWords) vs \(targetWords)")

        // Handle different word counts with dynamic alignment
        let alignmentResult = performDynamicWordAlignment(
            recognizedWords: recognizedWords,
            targetWords: targetWords
        )

        // If alignment suggests a high-confidence match, return it
        if alignmentResult.overallSimilarity >= threshold {
            return AnalysisResult(
                finalText: targetText,
                originalText: recognizedText,
                phoneticAccuracy: alignmentResult.overallSimilarity,
                levenshteinSimilarity: alignmentResult.levenshteinSimilarity,
                soundexSimilarity: alignmentResult.soundexSimilarity,
                overallConfidence: min(alignmentResult.overallSimilarity * 1.1, 1.0),
                matched: true
            )
        }

        // Fallback to word-by-word analysis
        var totalPhoneticAccuracy = 0.0
        var totalLevenshtein = 0.0
        var totalSoundex = 0.0
        var validComparisons = 0

        let maxCount = max(recognizedWords.count, targetWords.count)

        for i in 0..<maxCount {
            let recognizedWord = i < recognizedWords.count ? recognizedWords[i] : ""
            let targetWord = i < targetWords.count ? targetWords[i] : ""

            if !recognizedWord.isEmpty && !targetWord.isEmpty {
                let wordResult = analyzePhoneticMatch(
                    recognizedText: recognizedWord,
                    targetText: targetWord,
                    originalConfidence: originalConfidence,
                    threshold: lenientThreshold // Use more lenient threshold for individual words
                )

                totalPhoneticAccuracy += wordResult.phoneticAccuracy
                totalLevenshtein += wordResult.levenshteinSimilarity
                totalSoundex += wordResult.soundexSimilarity
                validComparisons += 1
            } else if recognizedWord.isEmpty || targetWord.isEmpty {
                // Penalty for missing words, but not zero
                totalPhoneticAccuracy += 0.3
                totalLevenshtein += 0.3
                totalSoundex += 0.3
                validComparisons += 1
            }
        }

        let validCount = max(validComparisons, 1)
        let avgPhoneticAccuracy = totalPhoneticAccuracy / Double(validCount)
        let avgLevenshtein = totalLevenshtein / Double(validCount)
        let avgSoundex = totalSoundex / Double(validCount)

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

    // MARK: - Dynamic Word Alignment

    private static func performDynamicWordAlignment(
        recognizedWords: [String],
        targetWords: [String]
    ) -> (overallSimilarity: Double, levenshteinSimilarity: Double, soundexSimilarity: Double) {

        let recCount = recognizedWords.count
        let targCount = targetWords.count

        // Handle exact word count matches
        if recCount == targCount {
            return calculateDirectWordComparison(recognizedWords: recognizedWords, targetWords: targetWords)
        }

        // Handle missing words (fast speech often drops function words)
        if recCount < targCount {
            return handleMissingWords(recognizedWords: recognizedWords, targetWords: targetWords)
        }

        // Handle extra words
        if recCount > targCount {
            return handleExtraWords(recognizedWords: recognizedWords, targetWords: targetWords)
        }

        return (0.0, 0.0, 0.0)
    }

    private static func calculateDirectWordComparison(
        recognizedWords: [String],
        targetWords: [String]
    ) -> (overallSimilarity: Double, levenshteinSimilarity: Double, soundexSimilarity: Double) {

        var totalSimilarity = 0.0
        var totalLevenshtein = 0.0
        var totalSoundex = 0.0

        for i in 0..<recognizedWords.count {
            let recWord = cleanText(recognizedWords[i])
            let targWord = cleanText(targetWords[i])

            let levSim = calculateLevenshteinSimilarity(recWord, targWord)
            let soundSim = calculateSoundexSimilarity(recWord, targWord)
            let phonSim = calculatePhoneticFeaturesSimilarity(recWord, targWord)

            let wordSimilarity = (levSim * 0.4) + (soundSim * 0.3) + (phonSim * 0.3)

            totalSimilarity += wordSimilarity
            totalLevenshtein += levSim
            totalSoundex += soundSim

            print("PhoneticAnalyzer DEBUG - Word pair '\(recWord)' vs '\(targWord)': similarity=\(wordSimilarity)")
        }

        let avgSimilarity = totalSimilarity / Double(recognizedWords.count)
        let avgLevenshtein = totalLevenshtein / Double(recognizedWords.count)
        let avgSoundex = totalSoundex / Double(recognizedWords.count)

        return (avgSimilarity, avgLevenshtein, avgSoundex)
    }

    private static func handleMissingWords(
        recognizedWords: [String],
        targetWords: [String]
    ) -> (overallSimilarity: Double, levenshteinSimilarity: Double, soundexSimilarity: Double) {

        // Common patterns for missing words in fast speech
        let commonFunctionWords = ["is", "a", "an", "the", "of", "in", "on", "at", "to", "for"]

        // Try to find the best alignment by inserting missing words
        var bestSimilarity = 0.0
        var bestLevenshtein = 0.0
        var bestSoundex = 0.0

        // Generate possible alignments by inserting function words
        let possibleAlignments = generateAlignments(
            shorter: recognizedWords,
            longer: targetWords,
            functionWords: commonFunctionWords
        )

        for alignment in possibleAlignments {
            let result = calculateDirectWordComparison(
                recognizedWords: alignment,
                targetWords: targetWords
            )

            if result.overallSimilarity > bestSimilarity {
                bestSimilarity = result.overallSimilarity
                bestLevenshtein = result.levenshteinSimilarity
                bestSoundex = result.soundexSimilarity
            }
        }

        // Apply bonus for successful missing word recovery
        bestSimilarity *= 1.05

        return (min(bestSimilarity, 1.0), bestLevenshtein, bestSoundex)
    }

    private static func handleExtraWords(
        recognizedWords: [String],
        targetWords: [String]
    ) -> (overallSimilarity: Double, levenshteinSimilarity: Double, soundexSimilarity: Double) {

        // Try removing words and finding best match
        var bestSimilarity = 0.0
        var bestLevenshtein = 0.0
        var bestSoundex = 0.0

        // Try removing each word one by one
        for i in 0..<recognizedWords.count {
            var modifiedWords = recognizedWords
            modifiedWords.remove(at: i)

            if modifiedWords.count == targetWords.count {
                let result = calculateDirectWordComparison(
                    recognizedWords: modifiedWords,
                    targetWords: targetWords
                )

                if result.overallSimilarity > bestSimilarity {
                    bestSimilarity = result.overallSimilarity
                    bestLevenshtein = result.levenshteinSimilarity
                    bestSoundex = result.soundexSimilarity
                }
            }
        }

        return (bestSimilarity, bestLevenshtein, bestSoundex)
    }

    private static func generateAlignments(
        shorter: [String],
        longer: [String],
        functionWords: [String]
    ) -> [[String]] {

        var alignments: [[String]] = []
        let diff = longer.count - shorter.count

        // Try inserting function words at different positions
        for insertPos in 0...shorter.count {
            for word in functionWords {
                var aligned = shorter
                for _ in 0..<diff {
                    aligned.insert(word, at: min(insertPos, aligned.count))
                }

                if aligned.count == longer.count {
                    alignments.append(aligned)
                }
            }
        }

        // Also try empty string insertions (word skipping)
        var aligned = shorter
        for _ in 0..<diff {
            aligned.insert("", at: 1) // Insert empty strings typically after first word
        }
        alignments.append(aligned)

        return alignments
    }

    // MARK: - Enhanced Similarity Calculations

    private static func calculateLevenshteinSimilarity(_ s1: String, _ s2: String) -> Double {
        let distance = levenshteinDistance(s1, s2)
        let maxLength = max(s1.count, s2.count)
        return maxLength > 0 ? 1.0 - (Double(distance) / Double(maxLength)) : 1.0
    }

    private static func calculateSoundexSimilarity(_ s1: String, _ s2: String) -> Double {
        return soundex(s1) == soundex(s2) ? 1.0 : 0.0
    }

    private static func calculatePhoneticFeaturesSimilarity(_ s1: String, _ s2: String) -> Double {
        let features1 = extractPhoneticFeatures(from: s1)
        let features2 = extractPhoneticFeatures(from: s2)

        let set1 = Set(features1)
        let set2 = Set(features2)

        let intersection = set1.intersection(set2)
        let union = set1.union(set2)

        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }

    private static func calculateStructuralSimilarity(_ s1: String, _ s2: String) -> Double {
        let len1 = s1.count
        let len2 = s2.count
        let lengthSim = 1.0 - abs(Double(len1 - len2)) / Double(max(len1, len2, 1))

        let syl1 = estimateSyllableCount(s1)
        let syl2 = estimateSyllableCount(s2)
        let syllableSim = 1.0 - abs(Double(syl1 - syl2)) / Double(max(syl1, syl2, 1))

        return (lengthSim * 0.5) + (syllableSim * 0.5)
    }

    // MARK: - Phonetic Feature Extraction

    private static func extractPhoneticFeatures(from word: String) -> [String] {
        var features: [String] = []
        let w = word.lowercased()

        // Extract consonant clusters
        features.append(contentsOf: extractConsonantClusters(from: w))

        // Extract vowel patterns
        features.append(contentsOf: extractVowelPatterns(from: w))

        // Extract phonetic characteristics
        if !w.isEmpty {
            features.append("start_" + String(w.first!))
            features.append("end_" + String(w.last!))
        }

        // Extract syllable information
        features.append("syllables_" + String(estimateSyllableCount(w)))

        return features
    }

    private static func extractConsonantClusters(from word: String) -> [String] {
        let consonants = "bcdfghjklmnpqrstvwxyz"
        var clusters: [String] = []
        var currentCluster = ""

        for char in word {
            if consonants.contains(char) {
                currentCluster.append(char)
            } else {
                if currentCluster.count > 0 {
                    clusters.append("cons_" + currentCluster)
                    currentCluster = ""
                }
            }
        }

        if !currentCluster.isEmpty {
            clusters.append("cons_" + currentCluster)
        }

        return clusters
    }

    private static func extractVowelPatterns(from word: String) -> [String] {
        let vowels = "aeiou"
        var patterns: [String] = []
        var currentPattern = ""

        for char in word {
            if vowels.contains(char) {
                currentPattern.append(char)
            } else {
                if !currentPattern.isEmpty {
                    patterns.append("vowel_" + currentPattern)
                    currentPattern = ""
                }
            }
        }

        if !currentPattern.isEmpty {
            patterns.append("vowel_" + currentPattern)
        }

        return patterns
    }

    private static func estimateSyllableCount(_ word: String) -> Int {
        let vowels = "aeiouAEIOU"
        var count = 0
        var previousWasVowel = false

        for char in word {
            let isVowel = vowels.contains(char)
            if isVowel && !previousWasVowel {
                count += 1
            }
            previousWasVowel = isVowel
        }

        return max(count, 1)
    }

    // MARK: - Utility Functions

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

    private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        let m = a.count
        let n = b.count

        if m == 0 { return n }
        if n == 0 { return m }

        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = a[i-1] == b[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }

        return matrix[m][n]
    }

    private static func soundex(_ string: String) -> String {
        let input = string.uppercased().filter { $0.isLetter }
        guard !input.isEmpty else { return "0000" }

        let firstLetter = String(input.first!)
        let mapping: [Character: Character] = [
            "B": "1", "F": "1", "P": "1", "V": "1",
            "C": "2", "G": "2", "J": "2", "K": "2", "Q": "2", "S": "2", "X": "2", "Z": "2",
            "D": "3", "T": "3",
            "L": "4",
            "M": "5", "N": "5",
            "R": "6"
        ]

        var soundexCode = firstLetter
        var previousCode: Character? = mapping[input.first!]

        for char in input.dropFirst() {
            if let code = mapping[char] {
                if code != previousCode {
                    soundexCode.append(code)
                }
                previousCode = code
            } else {
                previousCode = nil
            }

            if soundexCode.count >= 4 { break }
        }

        return soundexCode.padding(toLength: 4, withPad: "0", startingAt: 0)
    }
}
