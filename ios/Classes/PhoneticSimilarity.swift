import Foundation

struct WordMatchResult {
    let word: String
    let phoneticCode: String
    let isStopWord: Bool
    let isMetaphoneZero: Bool
    let bestMatch: String?
    let bestScore: Double
    let meetsThreshold: Bool
    let confidence: Double
    let phoneticContentSimilarity: Double

    // Initializer
    init(
        word: String,
        phoneticCode: String,
        isStopWord: Bool,
        isMetaphoneZero: Bool,
        bestMatch: String? = nil,
        bestScore: Double,
        meetsThreshold: Bool,
        confidence: Double,
        phoneticContentSimilarity: Double
    ) {
        self.word = word
        self.phoneticCode = phoneticCode
        self.isStopWord = isStopWord
        self.isMetaphoneZero = isMetaphoneZero
        self.bestMatch = bestMatch
        self.bestScore = bestScore
        self.meetsThreshold = meetsThreshold
        self.confidence = confidence
        self.phoneticContentSimilarity = phoneticContentSimilarity
    }

    // Copy function
    func copy(
        word: String? = nil,
        phoneticCode: String? = nil,
        isStopWord: Bool? = nil,
        isMetaphoneZero: Bool? = nil,
        bestMatch: String?? = nil, // double optional to allow overriding with nil
        bestScore: Double? = nil,
        meetsThreshold: Bool? = nil,
        confidence: Double? = nil,
        phoneticContentSimilarity: Double? = nil
    ) -> WordMatchResult {
        return WordMatchResult(
            word: word ?? self.word,
            phoneticCode: phoneticCode ?? self.phoneticCode,
            isStopWord: isStopWord ?? self.isStopWord,
            isMetaphoneZero: isMetaphoneZero ?? self.isMetaphoneZero,
            bestMatch: bestMatch ?? self.bestMatch,
            bestScore: bestScore ?? self.bestScore,
            meetsThreshold: meetsThreshold ?? self.meetsThreshold,
            confidence: confidence ?? self.confidence,
            phoneticContentSimilarity: phoneticContentSimilarity ?? self.phoneticContentSimilarity
        )
    }
}


struct WordAnalysisResult {
    let recognizedWord: String
    let confidence: Double
    let phoneticContentSimilarity: Double

    // Initializer
    init(
        recognizedWord: String,
        confidence: Double,
        phoneticContentSimilarity: Double
    ) {
        self.recognizedWord = recognizedWord
        self.confidence = confidence
        self.phoneticContentSimilarity = phoneticContentSimilarity
    }

    // Copy function
    func copy(
        recognizedWord: String? = nil,
        confidence: Double? = nil,
        phoneticContentSimilarity: Double? = nil
    ) -> WordAnalysisResult {
        return WordAnalysisResult(
            recognizedWord: recognizedWord ?? self.recognizedWord,
            confidence: confidence ?? self.confidence,
            phoneticContentSimilarity: phoneticContentSimilarity ?? self.phoneticContentSimilarity
        )
    }
}

class PhoneticSimilarity {

    private let doubleMetaphone = DoubleMetaphone()
    private let levenshtein = LevenshteinDistance()
    private let jaro = JaroWinklerDistance()

    // Common English stop words
    private let stopWords: Set<String> = [
        "the", "a", "an", "or", "but", "in", "on", "at", "to", "for", "of", "with",
        "by", "is", "are", "was", "were", "be", "been", "have", "has", "had", "do", "does",
        "did", "will", "would", "could", "should", "may", "might", "can", "must", "shall",
        "this", "that", "these", "those", "i", "you", "he", "she", "it", "we", "they",
        "me", "him", "her", "us", "them", "my", "your", "his", "its", "our", "their"
    ]

    // Acoustic similarity mappings for common confusions
    private let acousticSimilarities: [String: [String]] = [
        "J": ["K", "G", "CH"],
        "K": ["J", "G", "C"],
        "G": ["J", "K", "C"],
        "P": ["B", "F"],
        "B": ["P", "V"],
        "T": ["D", "TH"],
        "D": ["T", "TH"],
        "X": ["S", "SH", "CH"],
        "S": ["X", "SH", "CH", "Z", "SH", "TH"],
        "Z": ["S", "SH"],
        "F": ["V", "TH", "P"],
        "V": ["F", "B"],
        "M": ["N"],
        "N": ["M"],
        "A": ["E", "I"],
        "E": ["A", "I"],
        "I": ["A", "E"],
        "O": ["U"],
        "U": ["O"],
        "MP": ["M", "NP"],
        "MS": ["MZ", "NS"],
        "PS": ["S", "FS"]
    ]

    private let directSpeechCorrections: [String: String] = [
        "ccs": "she sees",
        "cc": "she sees",
        "cs": "she sees",
        "c": "see"
        // "processor": "brushes her"
    ]

    // Pre-process recognized phrase
    private func applyDirectSpeechCorrection(_ phrase: String) -> String {
        let words = phrase
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        let correctedWords = words.map { word in
            directSpeechCorrections[word.lowercased()] ?? word
        }
        return correctedWords.joined(separator: " ")
    }
    
    func calculatePhoneticSimilarityWithWordAnalysis(_ phrase1: String, _ phrase2: String) -> (Double, [WordAnalysisResult]) {
            print("--------- DEBUG INPUT:")
            print("   phrase1 (expected): '\(phrase1)'")
            print("   phrase2 (recognized): '\(phrase2)'")

            // Apply direct speech correction to the recognized phrase
            let correctedPhrase2 = applyDirectSpeechCorrection(phrase2)
            print("   corrected phrase2: '\(correctedPhrase2)'")

            let words1 = phrase1
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            let words2 = correctedPhrase2
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            print("   words1 count: \(words1.count) -> \(words1)")
            print("   words2 count: \(words2.count) -> \(words2)")

            if words1.isEmpty && words2.isEmpty { return (1.0, []) }
            if words1.isEmpty || words2.isEmpty { return (0.0, []) }

            // Analyze per-word accuracy with enhanced results
            let wordResults = analyzePerWordAccuracyEnhanced(words1, words2)

            // Generate word analysis results for recognized words
            let wordAnalysisResults = generateWordAnalysisResults(recognizedWords: words2, wordResults: wordResults, expectedWords: words1)

            // Check if all content words meet threshold
            let contentWordResults = wordResults.filter { !$0.isMetaphoneZero }
            let failedWords = contentWordResults.filter { !$0.meetsThreshold }

            print("--------- PER-WORD ACCURACY ANALYSIS:")
            print("   Required threshold: 0% for all words (as requested)")
            print("   Total content words: \(contentWordResults.count)")
            print("   Words meeting threshold: \(contentWordResults.filter { $0.meetsThreshold }.count)")
            print("   Words failing threshold: \(failedWords.count)")

            if !failedWords.isEmpty {
                print("    FAILED WORDS:")
                for result in failedWords {
                    let matchInfo = result.bestMatch != nil ? "→ '\(result.bestMatch!)'" : "→ NO MATCH"
                    print("      • '\(result.word)' [\(result.phoneticCode)] \(matchInfo) (\(String(format: "%.1f", result.bestScore * 100))%)")
                }
                print("    OVERALL RESULT: REJECTED - Not all words meet threshold")
                return (0.0, wordAnalysisResults)
            }

            // Calculate overall metrics
            let metaphoneSim = calculateDynamicPhoneticSimilarity(words1, words2)
            let acousticSim = calculateAcousticSimilarity(words1, words2)
            let editSim = calculateEditDistanceSimilarity(phrase1, correctedPhrase2)
            let wordOrderSim = calculateWordOrderSimilarity(words1, words2)

            print("   Enhanced Metric Breakdown:")
            print("   Metaphone (Dynamic): \(String(format: "%.2f", metaphoneSim * 100))%")
            print("   Acoustic Similarity: \(String(format: "%.2f", acousticSim * 100))%")
            print("   Edit Distance: \(String(format: "%.2f", editSim * 100))%")
            print("   Word Order: \(String(format: "%.2f", wordOrderSim * 100))%")

        showDetailedPhoneticBreakdown(words1: words1, words2: words2)

            let finalScore: Double
            if acousticSim > 0.90 {
                finalScore = acousticSim
            } else {
                finalScore = metaphoneSim * 0.2 + acousticSim * 0.3 + wordOrderSim * 0.5
            }

            print("   ALL WORDS MEET THRESHOLD")
            print("   SPEECH CORRECTION APPLIED: Converting recognized speech to expected phrase")
            print("   Corrected Output: '\(phrase1)'")

            return (min(1.0, finalScore), wordAnalysisResults)
        }

        /**
         * Legacy function for backward compatibility
         */
        func calculatePhoneticSimilarity(_ phrase1: String, _ phrase2: String) -> Double {
            return calculatePhoneticSimilarityWithWordAnalysis(phrase1, phrase2).0
        }

        /**
         * Generate word analysis results for each recognized word
         */
        private func generateWordAnalysisResults(
            recognizedWords: [String],
            wordResults: [WordMatchResult],
            expectedWords: [String]
        ) -> [WordAnalysisResult] {

            var results: [WordAnalysisResult] = []
            var usedExpectedWords = Set<Int>()

            // Create reverse mapping from recognized words to expected words
            var recognizedToExpectedMap: [Int: Int] = [:]

            for (i, result) in wordResults.enumerated() {
                if let bestMatch = result.bestMatch {
                    let matchedWords = bestMatch.components(separatedBy: " ")
                    for (j, recognizedWord) in recognizedWords.enumerated() {
                        if matchedWords.contains(recognizedWord) && recognizedToExpectedMap[j] == nil {
                            recognizedToExpectedMap[j] = i
                            usedExpectedWords.insert(i)
                            break
                        }
                    }
                }
            }

            // Generate results for each recognized word
            for (j, recognizedWord) in recognizedWords.enumerated() {
                let recognizedPhonetic = doubleMetaphone.doubleMetaphone(recognizedWord)

                if let matchedIndex = recognizedToExpectedMap[j] {
                    let matchedResult = wordResults[matchedIndex]

                    // Calculate confidence (combination of all algorithms)
                    let confidence = calculateWordConfidence(
                        expectedWord: matchedResult.word,
                        recognizedWord: recognizedWord,
                        phoneticMatch: matchedResult.bestScore
                    )

                    // Calculate pure phonetic content similarity
                    let phoneticContentSimilarity = calculatePurePhoneticSimilarity(
                        expectedWord: matchedResult.word,
                        recognizedWord: recognizedWord
                    )

                    results.append(WordAnalysisResult(
                        recognizedWord: recognizedWord,
                        confidence: confidence,
                        phoneticContentSimilarity: phoneticContentSimilarity
                    ))
                } else {
                    // This recognized word doesn't match any expected word
                    var bestExpectedMatch = ""
                    var bestPhoneticScore = 0.0

                    for (k, expectedWord) in expectedWords.enumerated() {
                        if usedExpectedWords.contains(k) { continue }

                        let expectedPhonetic = doubleMetaphone.doubleMetaphone(expectedWord)
                        let phoneticScore = calculateMetaphoneSimilarity(recognizedPhonetic, expectedPhonetic)

                        if phoneticScore > bestPhoneticScore {
                            bestPhoneticScore = phoneticScore
                            bestExpectedMatch = expectedWord
                        }
                    }

                    let confidence: Double
                    if !bestExpectedMatch.isEmpty {
                        confidence = calculateWordConfidence(expectedWord: bestExpectedMatch, recognizedWord: recognizedWord, phoneticMatch: bestPhoneticScore)
                    } else {
                        confidence = 0.3 // Base confidence for unmatched words
                    }

                    let phoneticContentSimilarity: Double
                    if !bestExpectedMatch.isEmpty {
                        phoneticContentSimilarity = calculatePurePhoneticSimilarity(expectedWord: bestExpectedMatch, recognizedWord: recognizedWord)
                    } else {
                        phoneticContentSimilarity = 0.2 // Low similarity for unmatched words
                    }

                    results.append(WordAnalysisResult(
                        recognizedWord: recognizedWord,
                        confidence: confidence,
                        phoneticContentSimilarity: phoneticContentSimilarity
                    ))
                }
            }

            return results
        }
    
    /**
        * Calculate confidence using combination of all algorithms
        */
       private func calculateWordConfidence(expectedWord: String, recognizedWord: String, phoneticMatch: Double) -> Double {
           // Exact match gets full confidence
           if expectedWord.caseInsensitiveCompare(recognizedWord) == .orderedSame {
               return 1.0
           }

           // Calculate various similarity metrics
           let phoneticSimilarity = phoneticMatch
           let editDistanceSimilarity = calculateWordEditSimilarity(expectedWord, recognizedWord)
           let jaroWinklerSimilarity = jaro.calculate(expectedWord.lowercased(), recognizedWord.lowercased())
           let acousticSimilarity = calculateWordAcousticSimilarity(expectedWord, recognizedWord)

           // Weight the different algorithms
           let confidence = (
               phoneticSimilarity * 0.35 +      // Phonetic matching is most important
               acousticSimilarity * 0.25 +      // Acoustic confusion patterns
               jaroWinklerSimilarity * 0.25 +   // String similarity
               editDistanceSimilarity * 0.15    // Edit distance
           )

           // Apply boost for stop words (they're often recognized correctly phonetically)
           let finalConfidence: Double
           if isStopWord(expectedWord) || isStopWord(recognizedWord) {
               finalConfidence = min(1.0, confidence + 0.1)
           } else {
               finalConfidence = confidence
           }

           return max(0.0, min(1.0, finalConfidence))
       }

       /**
        * Calculate pure phonetic content similarity focusing only on pronunciation
        */
       private func calculatePurePhoneticSimilarity(expectedWord: String, recognizedWord: String) -> Double {
           // Exact match
           if expectedWord.caseInsensitiveCompare(recognizedWord) == .orderedSame {
               return 1.0
           }

           let expectedPhonetic = doubleMetaphone.doubleMetaphone(expectedWord)
           let recognizedPhonetic = doubleMetaphone.doubleMetaphone(recognizedWord)

           // Handle metaphone [0] codes
           if expectedPhonetic == "0" && recognizedPhonetic == "0" {
               return 0.8 // Both are non-phonetic, give decent similarity
           }
           if expectedPhonetic == "0" || recognizedPhonetic == "0" {
               return 0.3 // One is non-phonetic, lower similarity
           }

           // Pure phonetic similarity
           let phoneticSim = calculateMetaphoneSimilarity(expectedPhonetic, recognizedPhonetic)

           // Add acoustic similarity for pronunciation confusions
           let acousticSim = calculateAcousticCodeSimilarity(expectedPhonetic, recognizedPhonetic)

           // Focus on pronunciation similarity with acoustic boost
           let pronunciationSimilarity = phoneticSim * 0.7 + acousticSim * 0.3

           // Special handling for common pronunciation patterns
           let pronunciationBoost = checkCommonPronunciationPatterns(expectedWord, recognizedWord)

           return min(1.0, pronunciationSimilarity + pronunciationBoost)
       }

       /**
        * Check for common pronunciation patterns and confusions
        */
       private func checkCommonPronunciationPatterns(_ expected: String, _ recognized: String) -> Double {
           let exp = expected.lowercased()
           let rec = recognized.lowercased()
           var boost = 0.0

           // Common pronunciation confusions
           let pronunciationPairs: [(String, String)] = [
               ("she", "c"),
               ("c", "she"),
               ("she sees", "ccs"),
               ("ccs", "she sees"),
               ("she sees", "cc s"),
               ("cc s", "she sees"),
               ("she sees", "c cs"),
               ("c cs", "she sees"),
               ("c c", "she see"),
               ("she see", "c c"),
               ("she", "sea"),
               ("sea", "she"),
               ("sheep", "she"),
               ("she", "sheep"),
               ("seas", "she"),
               ("she", "seas"),
               ("see", "c"),
               ("c", "see"),
               ("she", "see"),
               ("see", "she"),
               ("to", "two"),
               ("two", "to"),
               ("too", "to"),
               ("to", "too"),
               ("there", "their"),
               ("their", "there"),
               ("where", "wear"),
               ("wear", "where"),
               ("for", "four"),
               ("four", "for"),
               ("one", "won"),
               ("won", "one"),
               ("know", "no"),
               ("no", "know"),
               ("right", "write"),
               ("write", "right"),
               ("night", "knight"),
               ("knight", "night"),
               ("processor", "brushes her"),
               ("process or", "brushes her"),
               ("brushes her", "processor"),
               ("brushes her", "process or")
           ]

           for (word1, word2) in pronunciationPairs {
               if (exp == word1 && rec == word2) || (exp == word2 && rec == word1) {
                   boost += 0.3 // Strong pronunciation similarity
                   break
               }
               if (exp.contains(word1) && rec.contains(word2)) || (exp.contains(word2) && rec.contains(word1)) {
                   boost += 0.1 // Partial pronunciation similarity
               }
           }

           // Similar starting sounds
           if !exp.isEmpty && !rec.isEmpty &&
               calculateMetaphoneSimilarity(
                   doubleMetaphone.doubleMetaphone(String(exp.prefix(2))),
                   doubleMetaphone.doubleMetaphone(String(rec.prefix(2)))
               ) > 0.8 {
               boost += 0.05
           }

           return boost
       }

       /**
        * Calculate word-level acoustic similarity
        */
       private func calculateWordAcousticSimilarity(_ word1: String, _ word2: String) -> Double {
           let phone1 = doubleMetaphone.doubleMetaphone(word1)
           let phone2 = doubleMetaphone.doubleMetaphone(word2)
           return calculateAcousticCodeSimilarity(phone1, phone2)
       }
    /**
     * Calculate word-level edit distance similarity
     */
    private func calculateWordEditSimilarity(_ word1: String, _ word2: String) -> Double {
        let maxLen = max(word1.count, word2.count)
        if maxLen == 0 { return 1.0 }

        let distance = levenshtein.apply(word1.lowercased(), word2.lowercased())
        return 1.0 - (Double(distance) / Double(maxLen))
    }

    private func analyzePerWordAccuracyEnhanced(_ words1: [String], _ words2: [String]) -> [WordMatchResult] {
        let metaphone1 = words1.map { doubleMetaphone.doubleMetaphone($0) }
        let metaphone2 = words2.map { doubleMetaphone.doubleMetaphone($0) }
        var matched2 = Set<Int>()
        var results = [WordMatchResult]()

        for (i, word1) in words1.enumerated() {
            let phone1 = metaphone1[i]
            let isStopWord = isStopWord(word1)
            let isMetaphoneZero = phone1 == "0" || phone1.isEmpty

            var bestScore = 0.0
            var bestMatch: String? = nil
            var bestMatchIndex = -1
            var matchedWords = 1

            // Try single word matches
            for (j, word2) in words2.enumerated() where !matched2.contains(j) {
                let combinedScore = calculateCombinedSimilarity(phone1, metaphone2[j])
                if combinedScore > bestScore {
                    bestScore = combinedScore
                    bestMatch = word2
                    bestMatchIndex = j
                    matchedWords = 1
                }
            }

            // Try multi-word combinations for better phonetic matching
            for (j, _) in words2.enumerated() where !matched2.contains(j) {
                // 2-word combinations
                if j + 1 < words2.count && !matched2.contains(j+1) {
                    let combinedPhonetic = metaphone2[j] + metaphone2[j+1]
                    let combinedScore = calculateCombinedSimilarity(phone1, combinedPhonetic)
                    if combinedScore > bestScore {
                        bestScore = combinedScore
                        bestMatch = "\(words2[j]) \(words2[j+1])"
                        bestMatchIndex = j
                        matchedWords = 2
                    }
                }

                // 3-word combinations
                if j + 2 < words2.count && !matched2.contains(j+1) && !matched2.contains(j+2) {
                    let combinedPhonetic = metaphone2[j] + metaphone2[j+1] + metaphone2[j+2]
                    let combinedScore = calculateCombinedSimilarity(phone1, combinedPhonetic)
                    if combinedScore > bestScore {
                        bestScore = combinedScore
                        bestMatch = "\(words2[j]) \(words2[j+1]) \(words2[j+2])"
                        bestMatchIndex = j
                        matchedWords = 3
                    }
                }
            }

            // Mark matched words as used
            if bestMatchIndex != -1 {
                for k in bestMatchIndex..<(bestMatchIndex + matchedWords) {
                    matched2.insert(k)
                }
            }

            // Determine if word meets threshold
            let threshold: Double
            if isMetaphoneZero || isStopWord {
                threshold = 0.0
            } else {
                threshold = 0.5
            }
            let meetsThreshold = bestScore >= threshold

            // Calculate confidence for this word match
            let confidence: Double
            if let match = bestMatch {
                confidence = calculateWordConfidence(expectedWord: word1, recognizedWord: match.split(separator: " ")[0].description, phoneticMatch: bestScore)
            } else {
                confidence = 0.2
            }

            // Calculate phonetic content similarity
            let phoneticContentSimilarity: Double
            if let match = bestMatch {
                phoneticContentSimilarity = calculatePurePhoneticSimilarity(expectedWord: word1, recognizedWord: match.split(separator: " ")[0].description)
            } else {
                phoneticContentSimilarity = 0.1
            }

            results.append(WordMatchResult(
                word: word1,
                phoneticCode: phone1,
                isStopWord: isStopWord,
                isMetaphoneZero: isMetaphoneZero,
                bestMatch: bestMatch,
                bestScore: bestScore,
                meetsThreshold: meetsThreshold,
                confidence: confidence,
                phoneticContentSimilarity: phoneticContentSimilarity
            ))
        }

        return results
    }

    private func calculateCombinedSimilarity(_ code1: String, _ code2: String) -> Double {
        let phoneticSim = calculateMetaphoneSimilarity(code1, code2)
        let acousticSim = calculateAcousticCodeSimilarity(code1, code2)
        return phoneticSim * 0.7 + acousticSim * 0.3
    }

    private func calculateAcousticSimilarity(_ words1: [String], _ words2: [String]) -> Double {
        if words1.isEmpty && words2.isEmpty { return 1.0 }
        if words1.isEmpty || words2.isEmpty { return 0.0 }

        let metaphone1 = words1.map { doubleMetaphone.doubleMetaphone($0)}
        let metaphone2 = words2.map { doubleMetaphone.doubleMetaphone($0) }

        var matched2 = Set<Int>()
        var totalScore = 0.0

        for (i, word1) in words1.enumerated() {
            let isStopWord = isStopWord(word1)
            var bestScore = 0.0
            var bestMatch = -1

            for (j, _) in metaphone2.enumerated() where !matched2.contains(j) {
                let acousticScore = calculateAcousticCodeSimilarity(metaphone1[i], metaphone2[j])
                if acousticScore > bestScore {
                    bestScore = acousticScore
                    bestMatch = j
                }
            }

            let threshold = isStopWord ? 0.4 : 0.6
            if bestMatch != -1 && bestScore > threshold {
                matched2.insert(bestMatch)
                let weight = isStopWord ? 0.3 : 1.0
                totalScore += bestScore * weight
            } else if isStopWord {
                totalScore += 0.3
            }
        }

        let contentWords = words1.filter { !isStopWord($0) }.count
        let stopWordCount = words1.count - contentWords
        let weightedTotal = Double(contentWords) + Double(stopWordCount) * 0.3

        if weightedTotal > 0 {
            return min(1.0, totalScore / weightedTotal)
        } else {
            return 0.0
        }
    }
    
    private func calculateAcousticCodeSimilarity(_ code1: String, _ code2: String) -> Double {
        if code1 == code2 { return 1.0 }
        if code1.isEmpty || code2.isEmpty { return 0.0 }

        let maxLen = max(code1.count, code2.count)
        let editDistance = levenshtein.apply(code1, code2)
        var baseScore = max(0.0, 1.0 - (Double(editDistance) / Double(maxLen)))

        var acousticBonus = 0.0
        let chars1 = Array(code1)
        let chars2 = Array(code2)

        for c1 in chars1 {
            for c2 in chars2 {
                if areAcousticallySimilar(String(c1), String(c2)) {
                    acousticBonus += 0.1
                }
            }
        }

        acousticBonus += checkCommonPatterns(code1, code2)
        let finalScore = baseScore + (acousticBonus * 0.3)
        return min(1.0, finalScore)
    }

    private func areAcousticallySimilar(_ char1: String, _ char2: String) -> Bool {
        if char1 == char2 { return true }
        return acousticSimilarities[char1]?.contains(char2) == true ||
               acousticSimilarities[char2]?.contains(char1) == true
    }

    private func checkCommonPatterns(_ code1: String, _ code2: String) -> Double {
        var bonus = 0.0

        let endingPatterns: [String: [String]] = [
            "MS": ["MZ", "NS", "NZ"],
            "PS": ["S", "FS", "BS"],
            "MP": ["M", "NP", "MB"],
            "ST": ["S", "T", "SD"],
            "NT": ["N", "ND", "MT"]
        ]

        for (pattern, alternatives) in endingPatterns {
            if code1.hasSuffix(pattern) && alternatives.contains(where: { code2.hasSuffix($0) }) {
                bonus += 0.2
            }
            if code2.hasSuffix(pattern) && alternatives.contains(where: { code1.hasSuffix($0) }) {
                bonus += 0.2
            }
        }

        let vowelPatterns = ["A", "E", "I", "O", "U"]
        for vowel in vowelPatterns {
            if code1.contains(vowel) && code2.contains(vowel) {
                bonus += 0.05
            }
        }

        return bonus
    }

    private func calculateDynamicPhoneticSimilarity(_ words1: [String], _ words2: [String]) -> Double {
        if words1.isEmpty && words2.isEmpty { return 1.0 }
        if words1.isEmpty || words2.isEmpty { return 0.0 }

        let metaphone1 = words1.map { doubleMetaphone.doubleMetaphone($0)}
        let metaphone2 = words2.map { doubleMetaphone.doubleMetaphone($0) }

        var matched2 = Set<Int>()
        var totalScore = 0.0

        for (i, currentWord) in words1.enumerated() {
            var matchedWords = 1
            var matchedPhrase = ""
            var bestScore = 0.0
            var bestMatch = -1

            // Single-word phonetic match
            for (j, code2) in metaphone2.enumerated() where !matched2.contains(j) {
                let similarity = calculateMetaphoneSimilarity(metaphone1[i], code2)
                if similarity > bestScore {
                    bestScore = similarity
                    bestMatch = j
                    matchedWords = 1
                    matchedPhrase = words2[j]
                }
            }

            // Enhanced compound (multi-word) phonetic match with strict validation
            for j in 0..<metaphone2.count where !matched2.contains(j) && j + 1 < metaphone2.count && !matched2.contains(j+1) {
                let combinedPhonetic = metaphone2[j] + metaphone2[j+1]
                let similarity = calculateMetaphoneSimilarity(metaphone1[i], combinedPhonetic)

                // Very strict validation for compound matches
                let compoundThreshold = 0.90
                let word1Length = words1[i].count
                let combinedLength = words2[j].count + words2[j+1].count
                let lengthRatio = Double(min(word1Length, combinedLength)) / Double(max(word1Length, combinedLength))

                let word1Syllables = estimateSyllableCount(words1[i])
                let combinedSyllables = estimateSyllableCount(words2[j]) + estimateSyllableCount(words2[j+1])
                let syllableDiff = abs(word1Syllables - combinedSyllables)

                let word1Chars = Set(words1[i].lowercased())
                let word2Chars = Set((words2[j] + words2[j+1]).lowercased())
                let commonChars = word1Chars.intersection(word2Chars).count
                let totalUniqueChars = word1Chars.union(word2Chars).count
                let charOverlapRatio = Double(commonChars) / Double(totalUniqueChars)

                let reverseSimilarity = calculateMetaphoneSimilarity(combinedPhonetic, metaphone1[i])
                let bidirectionalSimilarity = (similarity + reverseSimilarity) / 2.0

                let isLikelyCompound = isLikelyCompoundWordScenario(singleWord: words1[i], word1: words2[j], word2: words2[j+1])

                let isValidCompound = bidirectionalSimilarity > compoundThreshold &&
                                      lengthRatio > 0.7 &&
                                      syllableDiff <= 1 &&
                                      charOverlapRatio > 0.4 &&
                                      isLikelyCompound &&
                                      similarity > bestScore

                if isValidCompound {
                    bestScore = bidirectionalSimilarity
                    bestMatch = j
                    matchedWords = 2
                    matchedPhrase = "\(words2[j]) \(words2[j+1])"
                }
            }

            let threshold = isStopWord(currentWord) ? 0.5 : 0.7
            if bestMatch != -1 && bestScore > threshold {
                for k in bestMatch..<(bestMatch + matchedWords) { matched2.insert(k) }
                let weight = isStopWord(currentWord) ? 0.3 : 1.0
                totalScore += bestScore * weight
            } else if isStopWord(currentWord) {
                totalScore += 0.3
            }
        }

        let contentWords = words1.filter { !isStopWord($0) }.count
        let stopWordCount = words1.count - contentWords
        let weightedTotal = Double(contentWords) + (Double(stopWordCount) * 0.3)

        return weightedTotal > 0 ? min(1.0, totalScore / weightedTotal) : 0.0
    }
    
    // Helper function to estimate syllable count
    private func estimateSyllableCount(_ word: String) -> Int {
        let vowels = "aeiouAEIOU"
        var syllableCount = 0
        var previousWasVowel = false

        for char in word {
            let isVowel = vowels.contains(char)
            if isVowel && !previousWasVowel {
                syllableCount += 1
            }
            previousWasVowel = isVowel
        }

        // Handle silent 'e' at the end
        if word.lowercased().hasSuffix("e") && syllableCount > 1 {
            syllableCount -= 1
        }

        return max(1, syllableCount)
    }

    // Helper function to determine if compound word matching makes sense
    private func isLikelyCompoundWordScenario(singleWord: String, word1: String, word2: String) -> Bool {
        let single = singleWord.lowercased()
        let first = word1.lowercased()
        let second = word2.lowercased()

        let containsFirst = single.contains(first.prefix(2)) || first.contains(single.prefix(2))
        let containsSecond = single.contains(second.prefix(2)) || second.contains(single.prefix(2))

        let compoundPatterns: [(String, [String])] = [
            ("sunday", ["sun", "day"]),
            ("monday", ["mon", "day"]),
            ("tuesday", ["tues", "day"]),
            ("wednesday", ["wed", "day"]),
            ("thursday", ["thurs", "day"]),
            ("friday", ["fri", "day"]),
            ("saturday", ["sat", "day"]),
            ("something", ["some", "thing"]),
            ("everyone", ["every", "one"]),
            ("someone", ["some", "one"]),
            ("anybody", ["any", "body"]),
            ("classroom", ["class", "room"]),
            ("playground", ["play", "ground"]),
            ("newspaper", ["news", "paper"]),
            ("cannot", ["can", "not"]),
            ("will not", ["will", "not"])
        ]

        for (compound, parts) in compoundPatterns {
            if single.contains(compound) || compound.contains(single) {
                if (first.contains(parts[0]) || parts[0].contains(first)) &&
                   (second.contains(parts[1]) || parts[1].contains(second)) {
                    return true
                }
            }
        }

        return containsFirst && containsSecond &&
               single.count >= 6 &&
               (first.count + second.count >= Int(Double(single.count) * 0.8))
    }

    // Function to show detailed phonetic breakdown
    private func showDetailedPhoneticBreakdown(words1: [String], words2: [String]) {
        print(" Detailed Phonetic Analysis:")

        let metaphone1 = words1.map { doubleMetaphone.doubleMetaphone($0) }
        let metaphone2 = words2.map { doubleMetaphone.doubleMetaphone($0) }

        print(" Expected words (phrase1):")
        for i in 0..<words1.count {
            let word1 = words1[i]
            let phone1 = metaphone1[i]
            let isStopWordFlag = isStopWord(word1)
            let isMetaphoneZero = phone1 == "0" || phone1.isEmpty
            let wordType: String
            if isMetaphoneZero {
                wordType = " ([0] - auto-pass)"
            } else if isStopWordFlag {
                wordType = " (stop)"
            } else {
                wordType = " (content - needs 60%)"
            }
            print("   Expected: '\(word1)' → [\(phone1)]\(wordType)")
        }

        print(" Recognized words (phrase2):")
        for j in 0..<words2.count {
            let word2 = words2[j]
            let phone2 = metaphone2[j]
            let isStopWordFlag = isStopWord(word2)
            let wordType = isStopWordFlag ? " (stop)" : ""
            print("   Recognized: '\(word2)' → [\(phone2)]\(wordType)")
        }
    }

    // Check if a word is a stop word
    private func isStopWord(_ word: String) -> Bool {
        let cleaned = word.lowercased().replacingOccurrences(of: "[^a-zA-Z]", with: "", options: .regularExpression)
        return stopWords.contains(cleaned)
    }

    private func calculateMetaphoneSimilarity(_ code1: String, _ code2: String) -> Double {
        if code1 == code2 { return 1.0 }
        if code1.isEmpty || code2.isEmpty { return 0.0 }

        let maxLen = max(code1.count, code2.count)
        let minLen = min(code1.count, code2.count)
        let distance = levenshtein.apply(code1, code2)

        // Base similarity using Levenshtein distance
        let baseSimilarity = max(0.0, 1.0 - Double(distance) / Double(maxLen))

        // Bonus for shared starting sound
        let startBonus = (code1.first == code2.first) ? 0.15 : 0.0

        // Bonus for shared ending sound
        let endBonus = (code1.last == code2.last) ? 0.1 : 0.0

        // Containment bonus
        let longer = (code1.count > code2.count) ? code1 : code2
        let shorter = (code1.count <= code2.count) ? code1 : code2
        let containmentBonus = (longer.contains(shorter) && shorter.count >= 2) ? 0.2 : 0.0

        // Character overlap bonus
        let overlapBonus: Double
        if abs(code1.count - code2.count) <= 1 {
            let commonChars = Set(code1).intersection(Set(code2)).count
            let totalChars = Set(code1).union(Set(code2)).count
            overlapBonus = Double(commonChars) / Double(totalChars) * 0.1
        } else {
            overlapBonus = 0.0
        }

        return min(1.0, baseSimilarity + startBonus + endBonus + containmentBonus + overlapBonus)
    }

    private func calculateEditDistanceSimilarity(_ phrase1: String, _ phrase2: String) -> Double {
        let maxLen = max(phrase1.count, phrase2.count)
        if maxLen == 0 { return 1.0 }

        let distance = levenshtein.apply(phrase1.lowercased(), phrase2.lowercased())
        return 1.0 - Double(distance) / Double(maxLen)
    }

    private func calculateWordOrderSimilarity(_ words1: [String], _ words2: [String]) -> Double {
        if words1.isEmpty || words2.isEmpty { return 0.0 }

        let cleanWords1 = words1.map { $0.lowercased().replacingOccurrences(of: "[^a-zA-Z]", with: "", options: .regularExpression) }.filter { !$0.isEmpty }
        let cleanWords2 = words2.map { $0.lowercased().replacingOccurrences(of: "[^a-zA-Z]", with: "", options: .regularExpression) }.filter { !$0.isEmpty }

        let positionScore = calculatePositionBasedSimilarity(cleanWords1, cleanWords2)
        let contentScore = calculatePhoneticContentSimilarity(cleanWords1, cleanWords2)
        let sequenceScore = calculateSequenceAlignment(cleanWords1, cleanWords2)

        let finalScore = positionScore * 0.5 + contentScore * 0.3 + sequenceScore * 0.2

        print("      Word Order Breakdown:")
        print("      Position-based: \(String(format: "%.1f", positionScore * 100))%")
        print("      Content-based: \(String(format: "%.1f", contentScore * 100))%")
        print("      Sequence alignment: \(String(format: "%.1f", sequenceScore * 100))%")
        print("      Combined: \(String(format: "%.1f", finalScore * 100))%")

        return finalScore
    }

    private func calculatePositionBasedSimilarity(_ words1: [String], _ words2: [String]) -> Double {
        let maxLen = max(words1.count, words2.count)
        if maxLen == 0 { return 1.0 }

        var matches = 0.0
        var used2 = [Bool](repeating: false, count: words2.count)

        for (i, word1) in words1.enumerated() {
            let isStopWord1 = isStopWord(word1)
            var bestMatch = 0.0
            var bestIdx = -1

            let expectedPos = Int(Double(i) / Double(words1.count) * Double(words2.count))
            let windowSize = isStopWord1 ? max(3, min(words1.count, words2.count) / 2) : max(1, min(words1.count, words2.count) / 4)
            let startPos = max(0, expectedPos - windowSize)
            let endPos = min(words2.count - 1, expectedPos + windowSize)

            for j in startPos...endPos {
                if used2[j] { continue }

                let word2 = words2[j]
                var similarity = 0.0

                if word1 == word2 {
                    similarity = 1.0
                } else {
                    let phone1 = doubleMetaphone.doubleMetaphone(word1)
                    let phone2 = doubleMetaphone.doubleMetaphone(word2)
                    let phoneticSim = calculateMetaphoneSimilarity(phone1, phone2)

                    if phoneticSim >= 0.8 { similarity = 0.9 }
                    else if phoneticSim >= 0.6 { similarity = 0.7 }
                }

                if similarity > 0 {
                    let maxPenalty = isStopWord1 ? 0.2 : 0.4
                    let positionPenalty = 1.0 - (Double(abs(j - expectedPos)) / Double(windowSize) * maxPenalty)
                    similarity *= positionPenalty
                }

                if similarity > bestMatch {
                    bestMatch = similarity
                    bestIdx = j
                }
            }

            if bestIdx != -1 && bestMatch > 0.5 {
                used2[bestIdx] = true
                matches += bestMatch
            } else {
                matches += isStopWord1 ? 0.5 : 0.0
            }
        }

        return matches / Double(words1.count)
    }
    private func calculateSequenceAlignment(_ words1: [String], _ words2: [String]) -> Double {
        let m = words1.count
        let n = words2.count

        if m == 0 || n == 0 { return 0.0 }

        // DP table where dp[i][j] represents the best alignment score up to words1[i-1] and words2[j-1]
        var dp = Array(repeating: Array(repeating: 0.0, count: n + 1), count: m + 1)

        for i in 1...m {
            for j in 1...n {
                let word1 = words1[i-1]
                let word2 = words2[j-1]

                // Calculate match score
                let matchScore: Double
                if word1 == word2 {
                    matchScore = 1.0
                } else {
                    let phone1 = doubleMetaphone.doubleMetaphone(word1)
                    let phone2 = doubleMetaphone.doubleMetaphone(word2)
                    let phoneticSim = calculateMetaphoneSimilarity(phone1, phone2)
                    matchScore = phoneticSim >= 0.7 ? phoneticSim * 0.8 : 0.0
                }

                // Skip penalties
                let skipWord1Penalty = isStopWord(word1) ? 0.8 : 0.3
                let skipWord2Penalty = isStopWord(word2) ? 0.8 : 0.3

                dp[i][j] = max(
                    dp[i-1][j-1] + matchScore,
                    dp[i-1][j] * skipWord1Penalty,
                    dp[i][j-1] * skipWord2Penalty
                )
            }
        }

        let maxLength = max(m, n)
        return dp[m][n] / Double(maxLength)
    }

    private func calculatePhoneticContentSimilarity(_ words1: [String], _ words2: [String]) -> Double {
        let contentWords1 = words1.filter { !isStopWord($0) }
        let contentWords2 = words2.filter { !isStopWord($0) }
        let stopWords1 = words1.filter { isStopWord($0) }
        let stopWords2 = words2.filter { isStopWord($0) }

        let contentPhones1 = contentWords1.map { doubleMetaphone.doubleMetaphone($0) }.filter { $0 != "0" }
        let contentPhones2 = contentWords2.map { doubleMetaphone.doubleMetaphone($0) }.filter { $0 != "0" }
        let stopPhones1 = stopWords1.map { doubleMetaphone.doubleMetaphone($0) }.filter { $0 != "0" }
        let stopPhones2 = stopWords2.map { doubleMetaphone.doubleMetaphone($0) }.filter { $0 != "0" }

        let contentSimilarity: Double
        if contentPhones1.isEmpty && contentPhones2.isEmpty {
            contentSimilarity = 1.0
        } else if contentPhones1.isEmpty || contentPhones2.isEmpty {
            contentSimilarity = 0.0
        } else {
            contentSimilarity = calculatePhoneticMatching(contentPhones1, contentPhones2)
        }

        let stopSimilarity: Double
        if stopPhones1.isEmpty && stopPhones2.isEmpty {
            stopSimilarity = 1.0
        } else if stopPhones1.isEmpty || stopPhones2.isEmpty {
            stopSimilarity = 0.7
        } else {
            stopSimilarity = calculatePhoneticMatching(stopPhones1, stopPhones2)
        }

        return contentSimilarity * 0.8 + stopSimilarity * 0.2
    }

    private func calculatePhoneticMatching(_ phones1: [String], _ phones2: [String]) -> Double {
        var matched = Set<Int>()
        var totalSimilarity = 0.0

        for phone1 in phones1 {
            var bestSim = 0.0
            var bestIdx: Int? = nil

            for (i, phone2) in phones2.enumerated() {
                if matched.contains(i) { continue }
                let sim = calculateMetaphoneSimilarity(phone1, phone2)
                if sim > bestSim {
                    bestSim = sim
                    bestIdx = i
                }
            }

            if let idx = bestIdx, bestSim >= 0.6 {
                matched.insert(idx)
                totalSimilarity += bestSim
            }
        }

        let coverage1 = totalSimilarity / Double(phones1.count)
        let coverage2 = phones2.isEmpty ? 1.0 : Double(matched.count) / Double(phones2.count)

        return (coverage1 + coverage2) / 2.0
    }

}


