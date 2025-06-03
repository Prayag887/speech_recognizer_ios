import Foundation

public class SoundexAlgorithm {

    public static func soundex(_ word: String) -> String {
        guard !word.isEmpty else { return "0000" }

        let cleanWord = word.uppercased().filter { $0.isLetter }
        guard !cleanWord.isEmpty else { return "0000" }

        var result = String(cleanWord.first!)
        var previousCode = getCode(cleanWord.first!)

        for char in cleanWord.dropFirst() {
            let code = getCode(char)
            if code != "0" && code != previousCode {
                result += code
                if result.count == 4 { break }
            }
            if code != "0" {
                previousCode = code
            }
        }

        // Pad with zeros if necessary
        while result.count < 4 {
            result += "0"
        }

        return String(result.prefix(4))
    }

    private static func getCode(_ char: Character) -> String {
        switch char {
        case "B", "F", "P", "V":
            return "1"
        case "C", "G", "J", "K", "Q", "S", "X", "Z":
            return "2"
        case "D", "T":
            return "3"
        case "L":
            return "4"
        case "M", "N":
            return "5"
        case "R":
            return "6"
        default:
            return "0"
        }
    }

    public static func phoneticSimilarity(_ word1: String, _ word2: String) -> Double {
        let soundex1 = soundex(word1)
        let soundex2 = soundex(word2)

        if soundex1 == soundex2 {
            return 1.0
        }

        // Calculate partial similarity based on matching characters
        let matches = zip(soundex1, soundex2).reduce(0) { count, pair in
            count + (pair.0 == pair.1 ? 1 : 0)
        }

        return Double(matches) / 4.0
    }
}