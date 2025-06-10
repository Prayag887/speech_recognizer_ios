import Foundation

public class LevenshteinDistance {
    
    public static func distance(_ s1: String, _ s2: String) -> Int {
        // Handle edge cases
        if s1.isEmpty { return s2.count }
        if s2.isEmpty { return s1.count }
        
        let s1Array = Array(s1.lowercased())
        let s2Array = Array(s2.lowercased())
        
        let m = s1Array.count
        let n = s2Array.count
        
        // Create a matrix
        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        // Initialize first row and column
        for i in 0...m {
            matrix[i][0] = i
        }
        for j in 0...n {
            matrix[0][j] = j
        }
        
        // Fill the matrix
        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[m][n]
    }
    
    public static func similarity(_ s1: String, _ s2: String) -> Double {
        let distance = self.distance(s1, s2)
        let maxLength = max(s1.count, s2.count)
        
        if maxLength == 0 {
            return 1.0
        }
        
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    public static func normalizedSimilarity(_ s1: String, _ s2: String) -> Double {
        let distance = self.distance(s1, s2)
        let maxLength = max(s1.count, s2.count)
        
        if maxLength == 0 {
            return 1.0
        }
        
        return (Double(maxLength - distance) / Double(maxLength)) * 100.0
    }
}
