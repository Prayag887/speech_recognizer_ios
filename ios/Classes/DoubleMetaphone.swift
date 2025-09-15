import Foundation

public class DoubleMetaphone {
    private static let vowels = "AEIOUY"
    private static let silentStart = ["GN", "KN", "PN", "WR", "PS"]
    private static let l_r_n_m_b_h_f_v_w_space = ["L", "R", "N", "M", "B", "H", "F", "V", "W", " "]
    private static let es_ep_eb_el_ey_ib_il_in_ie_ei_er = ["ES", "EP", "EB", "EL", "EY", "IB", "IL", "IN", "IE", "EI", "ER"]
    private static let l_t_k_s_n_m_b_z = ["L", "T", "K", "S", "N", "M", "B", "Z"]
    
    private var maxCodeLen: Int
    
    public init(maxCodeLen: Int = 4) {
        self.maxCodeLen = maxCodeLen
    }
    
    public func doubleMetaphone(_ value: String) -> String {
        return doubleMetaphone(value, alternate: false)
    }
    
    public func doubleMetaphone(_ value: String, alternate: Bool) -> String {
        guard let cleaned = cleanInput(value) else { return "" }
        
        let slavoGermanic = isSlavoGermanic(cleaned)
        var index = isSilentStart(cleaned) ? 1 : 0
        let result = DoubleMetaphoneResult(maxLength: maxCodeLen)
        
        while !result.isComplete() && index <= cleaned.count - 1 {
            let char = cleaned[cleaned.index(cleaned.startIndex, offsetBy: index)]
            
            switch char {
            case "A", "E", "I", "O", "U", "Y":
                index = handleAEIOUY(result, index)
            case "B":
                result.append("P")
                index = charAt(cleaned, index + 1) == "B" ? index + 2 : index + 1
            case "C":
                index = handleC(cleaned, result, index)
            case "D":
                index = handleD(cleaned, result, index)
            case "F":
                result.append("F")
                index = charAt(cleaned, index + 1) == "F" ? index + 2 : index + 1
            case "G":
                index = handleG(cleaned, result, index, slavoGermanic)
            case "H":
                index = handleH(cleaned, result, index)
            case "J":
                index = handleJ(cleaned, result, index, slavoGermanic)
            case "K":
                result.append("K")
                index = charAt(cleaned, index + 1) == "K" ? index + 2 : index + 1
            case "L":
                index = handleL(cleaned, result, index)
            case "M":
                result.append("M")
                index = conditionM0(cleaned, index) ? index + 2 : index + 1
            case "N":
                result.append("N")
                index = charAt(cleaned, index + 1) == "N" ? index + 2 : index + 1
            case "P":
                index = handleP(cleaned, result, index)
            case "Q":
                result.append("K")
                index = charAt(cleaned, index + 1) == "Q" ? index + 2 : index + 1
            case "R":
                index = handleR(cleaned, result, index, slavoGermanic)
            case "S":
                index = handleS(cleaned, result, index, slavoGermanic)
            case "T":
                index = handleT(cleaned, result, index)
            case "V":
                result.append("F")
                index = charAt(cleaned, index + 1) == "V" ? index + 2 : index + 1
            case "W":
                index = handleW(cleaned, result, index)
            case "X":
                index = handleX(cleaned, result, index)
            case "Z":
                index = handleZ(cleaned, result, index, slavoGermanic)
            case "Ç":
                result.append("S")
                index += 1
            case "Ñ":
                result.append("N")
                index += 1
            default:
                index += 1
            }
        }
        
        return alternate ? result.getAlternate() : result.getPrimary()
    }
    
    public func isDoubleMetaphoneEqual(_ value1: String, _ value2: String) -> Bool {
        return isDoubleMetaphoneEqual(value1, value2, alternate: false)
    }
    
    public func isDoubleMetaphoneEqual(_ value1: String, _ value2: String, alternate: Bool) -> Bool {
        return doubleMetaphone(value1, alternate: alternate) == doubleMetaphone(value2, alternate: alternate)
    }
    
    // MARK: - Private Helper Methods
    
    private func handleAEIOUY(_ result: DoubleMetaphoneResult, _ index: Int) -> Int {
        if index == 0 {
            result.append("A")
        }
        return index + 1
    }
    
    private func handleC(_ value: String, _ result: DoubleMetaphoneResult, _ index: Int) -> Int {
        var newIndex = index
        
        if conditionC0(value, index) {
            result.append("K")
            newIndex += 2
        } else if index == 0 && contains(value, start: index, length: 6, "CAESAR") {
            result.append("S")
            newIndex += 2
        } else if contains(value, start: index, length: 2, "CH") {
            newIndex = handleCH(value, result, index)
        } else if contains(value, start: index, length: 2, "CZ") && !contains(value, start: index - 2, length: 4, "WICZ") {
            result.append("S", "X")
            newIndex += 2
        } else if contains(value, start: index + 1, length: 3, "CIA") {
            result.append("X")
            newIndex += 3
        } else {
            if contains(value, start: index, length: 2, "CC") && (index != 1 || charAt(value, 0) != "M") {
                return handleCC(value, result, index)
            }
            
            if contains(value, start: index, length: 2, "CK", "CG", "CQ") {
                result.append("K")
                newIndex += 2
            } else if contains(value, start: index, length: 2, "CI", "CE", "CY") {
                if contains(value, start: index, length: 3, "CIO", "CIE", "CIA") {
                    result.append("S", "X")
                } else {
                    result.append("S")
                }
                newIndex += 2
            } else {
                result.append("K")
                if contains(value, start: index + 1, length: 2, " C", " Q", " G") {
                    newIndex += 3
                } else if contains(value, start: index + 1, length: 1, "C", "K", "Q") && !contains(value, start: index + 1, length: 2, "CE", "CI") {
                    newIndex += 2
                } else {
                    newIndex += 1
                }
            }
        }
        
        return newIndex
    }
    
    private func handleCC(_ value: String, _ result: DoubleMetaphoneResult, _ index: Int) -> Int {
        if contains(value, start: index + 2, length: 1, "I", "E", "H") && !contains(value, start: index + 2, length: 2, "HU") {
            if (index != 1 || charAt(value, index - 1) != "A") && !contains(value, start: index - 1, length: 5, "UCCEE", "UCCES") {
                result.append("X")
            } else {
                result.append("KS")
            }
            return index + 3
        } else {
            result.append("K")
            return index + 2
        }
    }
    
    private func handleCH(_ value: String, _ result: DoubleMetaphoneResult, _ index: Int) -> Int {
        if index > 0 && contains(value, start: index, length: 4, "CHAE") {
            result.append("K", "X")
            return index + 2
        } else if conditionCH0(value, index) {
            result.append("K")
            return index + 2
        } else if conditionCH1(value, index) {
            result.append("K")
            return index + 2
        } else {
            if index > 0 {
                if contains(value, start: 0, length: 2, "MC") {
                    result.append("K")
                } else {
                    result.append("X", "K")
                }
            } else {
                result.append("X")
            }
            return index + 2
        }
    }
    
    private func handleD(_ value: String, _ result: DoubleMetaphoneResult, _ index: Int) -> Int {
        if contains(value, start: index, length: 2, "DG") {
            if contains(value, start: index + 2, length: 1, "I", "E", "Y") {
                result.append("J")
                return index + 3
            } else {
                result.append("TK")
                return index + 2
            }
        } else if contains(value, start: index, length: 2, "DT", "DD") {
            result.append("T")
            return index + 2
        } else {
            result.append("T")
            return index + 1
        }
    }
    
    private func handleG(_ value: String, _ result: DoubleMetaphoneResult, _ index: Int, _ slavoGermanic: Bool) -> Int {
        if charAt(value, index + 1) == "H" {
            return handleGH(value, result, index)
        } else if charAt(value, index + 1) == "N" {
            if index == 1 && isVowel(charAt(value, 0)) && !slavoGermanic {
                result.append("KN", "N")
            } else if !contains(value, start: index + 2, length: 2, "EY") && charAt(value, index + 1) != "Y" && !slavoGermanic {
                result.append("N", "KN")
            } else {
                result.append("KN")
            }
            return index + 2
        } else if contains(value, start: index + 1, length: 2, "LI") && !slavoGermanic {
            result.append("KL", "L")
            return index + 2
        } else if index != 0 || (charAt(value, index + 1) != "Y" && !contains(value, start: index + 1, length: 2, DoubleMetaphone.es_ep_eb_el_ey_ib_il_in_ie_ei_er)) {
            if (contains(value, start: index + 1, length: 2, "ER") || charAt(value, index + 1) == "Y") && !contains(value, start: 0, length: 6, "DANGER", "RANGER", "MANGER") && !contains(value, start: index - 1, length: 1, "E", "I") && !contains(value, start: index - 1, length: 3, "RGY", "OGY") {
                result.append("K", "J")
                return index + 2
            } else if !contains(value, start: index + 1, length: 1, "E", "I", "Y") && !contains(value, start: index - 1, length: 4, "AGGI", "OGGI") {
                if charAt(value, index + 1) == "G" {
                    result.append("K")
                    return index + 2
                } else {
                    result.append("K")
                    return index + 1
                }
            } else {
                if !contains(value, start: 0, length: 4, "VAN ", "VON ") && !contains(value, start: 0, length: 3, "SCH") && !contains(value, start: index + 1, length: 2, "ET") {
                    if contains(value, start: index + 1, length: 3, "IER") {
                        result.append("J")
                    } else {
                        result.append("J", "K")
                    }
                } else {
                    result.append("K")
                }
                return index + 2
            }
        } else {
            result.append("K", "J")
            return index + 2
        }
    }
    
    private func handleGH(_ value: String, _ result: DoubleMetaphoneResult, _ index: Int) -> Int {
        if index > 0 && !isVowel(charAt(value, index - 1)) {
            result.append("K")
            return index + 2
        } else if index == 0 {
            if charAt(value, index + 2) == "I" {
                result.append("J")
            } else {
                result.append("K")
            }
            return index + 2
        } else if (index <= 1 || !contains(value, start: index - 2, length: 1, "B", "H", "D")) && (index <= 2 || !contains(value, start: index - 3, length: 1, "B", "H", "D")) && (index <= 3 || !contains(value, start: index - 4, length: 1, "B", "H")) {
            if index > 2 && charAt(value, index - 1) == "U" && contains(value, start: index - 3, length: 1, "C", "G", "L", "R", "T") {
                result.append("F")
            } else if index > 0 && charAt(value, index - 1) != "I" {
                result.append("K")
            }
            return index + 2
        } else {
            return index + 2
        }
    }
    
    private func handleH(_ value: String, _ result: DoubleMetaphoneResult, _ index: Int) -> Int {
        if (index == 0 || isVowel(charAt(value, index - 1))) && isVowel(charAt(value, index + 1)) {
            result.append("H")
            return index + 2
        } else {
            return index + 1
        }
    }
    
    private func handleJ(_ value: String, _ result: DoubleMetaphoneResult, _ index: Int, _ slavoGermanic: Bool) -> Int {
        if !contains(value, start: index, length: 4, "JOSE") && !contains(value, start: 0, length: 4, "SAN ") {
            if index == 0 && !contains(value, start: index, length: 4, "JOSE") {
                result.append("J", "A")
            } else if !isVowel(charAt(value, index - 1)) || slavoGermanic || (charAt(value, index + 1) != "A" && charAt(value, index + 1) != "O") {
                if index == value.count - 1 {
                    result.append("J", " ")
                } else if !contains(value, start: index + 1, length: 1, DoubleMetaphone.l_t_k_s_n_m_b_z) && !contains(value, start: index - 1, length: 1, "S", "K", "L") {
                    result.append("J")
                }
            } else {
                result.append("J", "H")
            }
            
            if charAt(value, index + 1) == "J" {
                return index + 2
            } else {
                return index + 1
            }
        } else {
            if (index != 0 || charAt(value, index + 4) != " ") && value.count != 4 && !contains(value, start: 0, length: 4, "SAN ") {
                result.append("J", "H")
            } else {
                result.append("H")
            }
            return index + 1
        }
    }
    
    private func handleL(_ value: String, _ result: DoubleMetaphoneResult, _ index: Int) -> Int {
        if charAt(value, index + 1) == "L" {
            if conditionL0(value, index) {
                result.appendPrimary("L")
            } else {
                result.append("L")
            }
            return index + 2
        } else {
            result.append("L")
            return index + 1
        }
    }
    
    private func handleP(_ value: String, _ result: DoubleMetaphoneResult, _ index: Int) -> Int {
        if charAt(value, index + 1) == "H" {
            result.append("F")
            return index + 2
        } else {
            result.append("P")
            return contains(value, start: index + 1, length: 1, "P", "B") ? index + 2 : index + 1
        }
    }
    
    private func handleR(_ value: String, _ result: DoubleMetaphoneResult, _ index: Int, _ slavoGermanic: Bool) -> Int {
        if index == value.count - 1 && !slavoGermanic && contains(value, start: index - 2, length: 2, "IE") && !contains(value, start: index - 4, length: 2, "ME", "MA") {
            result.appendAlternate("R")
        } else {
            result.append("R")
        }
        
        return charAt(value, index + 1) == "R" ? index + 2 : index + 1
    }
    
    private func handleS(_ value: String, _ result: DoubleMetaphoneResult, _ index: Int, _ slavoGermanic: Bool) -> Int {
        if contains(value, start: index - 1, length: 3, "ISL", "YSL") {
            return index + 1
        } else if index == 0 && contains(value, start: index, length: 5, "SUGAR") {
            result.append("X", "S")
            return index + 1
        } else if contains(value, start: index, length: 2, "SH") {
            if contains(value, start: index + 1, length: 4, "HEIM", "HOEK", "HOLM", "HOLZ") {
                result.append("S")
            } else {
                result.append("X")
            }
            return index + 2
        } else if !contains(value, start: index, length: 3, "SIO", "SIA") && !contains(value, start: index, length: 4, "SIAN") {
            if (index != 0 || !contains(value, start: index + 1, length: 1, "M", "N", "L", "W")) && !contains(value, start: index + 1, length: 1, "Z") {
                if contains(value, start: index, length: 2, "SC") {
                    return handleSC(value, result, index)
                } else {
                    if index == value.count - 1 && contains(value, start: index - 2, length: 2, "AI", "OI") {
                        result.appendAlternate("S")
                    } else {
                        result.append("S")
                    }
                    return contains(value, start: index + 1, length: 1, "S", "Z") ? index + 2 : index + 1
                }
            } else {
                result.append("S", "X")
                return contains(value, start: index + 1, length: 1, "Z") ? index + 2 : index + 1
            }
        } else {
            if slavoGermanic {
                result.append("S")
            } else {
                result.append("S", "X")
            }
            return index + 3
        }
    }
    
    private func handleSC(_ value: String, _ result: DoubleMetaphoneResult, _ index: Int) -> Int {
        if charAt(value, index + 2) == "H" {
            if contains(value, start: index + 3, length: 2, "OO", "ER", "EN", "UY", "ED", "EM") {
                if contains(value, start: index + 3, length: 2, "ER", "EN") {
                    result.append("X", "SK")
                } else {
                    result.append("SK")
                }
            } else if index == 0 && !isVowel(charAt(value, 3)) && charAt(value, 3) != "W" {
                result.append("X", "S")
            } else {
                result.append("X")
            }
        } else if contains(value, start: index + 2, length: 1, "I", "E", "Y") {
            result.append("S")
        } else {
            result.append("SK")
        }
        return index + 3
    }
    
    private func handleT(_ value: String, _ result: DoubleMetaphoneResult, _ index: Int) -> Int {
        if contains(value, start: index, length: 4, "TION") {
            result.append("X")
            return index + 3
        } else if contains(value, start: index, length: 3, "TIA", "TCH") {
            result.append("X")
            return index + 3
        } else if !contains(value, start: index, length: 2, "TH") && !contains(value, start: index, length: 3, "TTH") {
            result.append("T")
            return contains(value, start: index + 1, length: 1, "T", "D") ? index + 2 : index + 1
        } else {
            if !contains(value, start: index + 2, length: 2, "OM", "AM") && !contains(value, start: 0, length: 4, "VAN ", "VON ") && !contains(value, start: 0, length: 3, "SCH") {
                result.append("0", "T")
            } else {
                result.append("T")
            }
            return index + 2
        }
    }
    
    private func handleW(_ value: String, _ result: DoubleMetaphoneResult, _ index: Int) -> Int {
        if contains(value, start: index, length: 2, "WR") {
            result.append("R")
            return index + 2
        } else if index != 0 || (!isVowel(charAt(value, index + 1)) && !contains(value, start: index, length: 2, "WH")) {
            if (index != value.count - 1 || !isVowel(charAt(value, index - 1))) && !contains(value, start: index - 1, length: 5, "EWSKI", "EWSKY", "OWSKI", "OWSKY") && !contains(value, start: 0, length: 3, "SCH") {
                if contains(value, start: index, length: 4, "WICZ", "WITZ") {
                    result.append("TS", "FX")
                    return index + 4
                } else {
                    return index + 1
                }
            } else {
                result.appendAlternate("F")
                return index + 1
            }
        } else {
            if isVowel(charAt(value, index + 1)) {
                result.append("A", "F")
            } else {
                result.append("A")
            }
            return index + 1
        }
    }
    
    private func handleX(_ value: String, _ result: DoubleMetaphoneResult, _ index: Int) -> Int {
        if index == 0 {
            result.append("S")
            return index + 1
        } else {
            if index != value.count - 1 || (!contains(value, start: index - 3, length: 3, "IAU", "EAU") && !contains(value, start: index - 2, length: 2, "AU", "OU")) {
                result.append("KS")
            }
            return contains(value, start: index + 1, length: 1, "C", "X") ? index + 2 : index + 1
        }
    }
    
    private func handleZ(_ value: String, _ result: DoubleMetaphoneResult, _ index: Int, _ slavoGermanic: Bool) -> Int {
        if charAt(value, index + 1) == "H" {
            result.append("J")
            return index + 2
        } else {
            if !contains(value, start: index + 1, length: 2, "ZO", "ZI", "ZA") && (!slavoGermanic || index <= 0 || charAt(value, index - 1) == "T") {
                result.append("S")
            } else {
                result.append("S", "TS")
            }
            return charAt(value, index + 1) == "Z" ? index + 2 : index + 1
        }
    }
    
    private func conditionC0(_ value: String, _ index: Int) -> Bool {
        if contains(value, start: index, length: 4, "CHIA") {
            return true
        } else if index <= 1 {
            return false
        } else if isVowel(charAt(value, index - 2)) {
            return false
        } else if !contains(value, start: index - 1, length: 3, "ACH") {
            return false
        } else {
            let c = charAt(value, index + 2)
            return c != "I" && c != "E" || contains(value, start: index - 2, length: 6, "BACHER", "MACHER")
        }
    }
    
    private func conditionCH0(_ value: String, _ index: Int) -> Bool {
        if index != 0 {
            return false
        } else if !contains(value, start: index + 1, length: 5, "HARAC", "HARIS") && !contains(value, start: index + 1, length: 3, "HOR", "HYM", "HIA", "HEM") {
            return false
        } else {
            return !contains(value, start: 0, length: 5, "CHORE")
        }
    }
    
    private func conditionCH1(_ value: String, _ index: Int) -> Bool {
        return contains(value, start: 0, length: 4, "VAN ", "VON ") || contains(value, start: 0, length: 3, "SCH") || contains(value, start: index - 2, length: 6, "ORCHES", "ARCHIT", "ORCHID") || contains(value, start: index + 2, length: 1, "T", "S") || ((contains(value, start: index - 1, length: 1, "A", "O", "U", "E") || index == 0) && (contains(value, start: index + 2, length: 1, DoubleMetaphone.l_r_n_m_b_h_f_v_w_space) || index + 1 == value.count - 1))
    }
    
    private func conditionL0(_ value: String, _ index: Int) -> Bool {
        if index == value.count - 3 && contains(value, start: index - 1, length: 4, "ILLO", "ILLA", "ALLE") {
            return true
        } else {
            return (contains(value, start: value.count - 2, length: 2, "AS", "OS") || contains(value, start: value.count - 1, length: 1, "A", "O")) && contains(value, start: index - 1, length: 4, "ALLE")
        }
    }
    
    private func conditionM0(_ value: String, _ index: Int) -> Bool {
        if charAt(value, index + 1) == "M" {
            return true
        } else {
            return contains(value, start: index - 1, length: 3, "UMB") && (index + 1 == value.count - 1 || contains(value, start: index + 2, length: 2, "ER"))
        }
    }
    
    private func isSlavoGermanic(_ value: String) -> Bool {
        return value.contains("W") || value.contains("K") || value.contains("CZ") || value.contains("WITZ")
    }
    
    private func isVowel(_ char: Character) -> Bool {
        return DoubleMetaphone.vowels.contains(char)
    }
    
    private func isSilentStart(_ value: String) -> Bool {
        for element in DoubleMetaphone.silentStart {
            if value.hasPrefix(element) {
                return true
            }
        }
        return false
    }
    
    private func cleanInput(_ input: String?) -> String? {
        guard let input = input else { return nil }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed.uppercased()
    }
    
    private func charAt(_ value: String, _ index: Int) -> Character {
        guard index >= 0 && index < value.count else { return Character("\0") }
        return value[value.index(value.startIndex, offsetBy: index)]
    }
    
    private func contains(_ value: String, start: Int, length: Int, _ criteria: String...) -> Bool {
        guard start >= 0 && start + length <= value.count else { return false }
        
        let startIndex = value.index(value.startIndex, offsetBy: start)
        let endIndex = value.index(startIndex, offsetBy: length)
        let target = String(value[startIndex..<endIndex])
        
        return criteria.contains(target)
    }
    
    private func contains(_ value: String, start: Int, length: Int, _ criteria: [String]) -> Bool {
        guard start >= 0 && start + length <= value.count else { return false }
        
        let startIndex = value.index(value.startIndex, offsetBy: start)
        let endIndex = value.index(startIndex, offsetBy: length)
        let target = String(value[startIndex..<endIndex])
        
        return criteria.contains(target)
    }
    
    // MARK: - Result Class
    
    private class DoubleMetaphoneResult {
        private var primary: String
        private var alternate: String
        private let maxLength: Int
        
        init(maxLength: Int) {
            self.maxLength = maxLength
            self.primary = ""
            self.alternate = ""
        }
        
        func append(_ value: String) {
            appendPrimary(value)
            appendAlternate(value)
        }
        
        func append(_ primary: String, _ alternate: String) {
            appendPrimary(primary)
            appendAlternate(alternate)
        }
        
        func appendPrimary(_ value: String) {
            let addChars = maxLength - primary.count
            if value.count <= addChars {
                self.primary += value
            } else {
                self.primary += String(value.prefix(addChars))
            }
        }
        
        func appendAlternate(_ value: String) {
            let addChars = maxLength - alternate.count
            if value.count <= addChars {
                self.alternate += value
            } else {
                self.alternate += String(value.prefix(addChars))
            }
        }
        
        func getPrimary() -> String {
            return primary
        }
        
        func getAlternate() -> String {
            return alternate
        }
        
        func isComplete() -> Bool {
            return primary.count >= maxLength && alternate.count >= maxLength
        }
    }
}