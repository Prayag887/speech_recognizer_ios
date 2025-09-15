class JaroWinklerDistance {

    func calculate(_ s1: String, _ s2: String) -> Double {
        if s1 == s2 { return 1.0 }

        let len1 = s1.count
        let len2 = s2.count

        if len1 == 0 || len2 == 0 { return 0.0 }

        let matchWindow = max(len1, len2) / 2 - 1
        if matchWindow < 0 { return 0.0 }

        var s1Matches = Array(repeating: false, count: len1)
        var s2Matches = Array(repeating: false, count: len2)

        let s1Chars = Array(s1)
        let s2Chars = Array(s2)

        var matches = 0
        var transpositions = 0

        // Find matches
        for i in 0..<len1 {
            let start = max(0, i - matchWindow)
            let end = min(i + matchWindow + 1, len2)

            for j in start..<end {
                if s2Matches[j] || s1Chars[i] != s2Chars[j] { continue }
                s1Matches[i] = true
                s2Matches[j] = true
                matches += 1
                break
            }
        }

        if matches == 0 { return 0.0 }

        // Find transpositions
        var k = 0
        for i in 0..<len1 {
            if !s1Matches[i] { continue }
            while !s2Matches[k] { k += 1 }
            if s1Chars[i] != s2Chars[k] { transpositions += 1 }
            k += 1
        }

        let jaro = (Double(matches) / Double(len1) +
                    Double(matches) / Double(len2) +
                    Double(matches) - Double(transpositions) / 2.0) / 3.0

        // Winkler modification
        var prefix = 0
        for i in 0..<min(len1, len2, 4) {
            if s1Chars[i] == s2Chars[i] { prefix += 1 } else { break }
        }

        return jaro + (0.1 * Double(prefix) * (1.0 - jaro))
    }
}
