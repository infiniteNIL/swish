import BigInt

extension Parser {

    // MARK: - Number parsing helpers

    func stripSign(_ text: String) -> (negative: Bool, rest: String) {
        if text.hasPrefix("-") { return (true, String(text.dropFirst())) }
        if text.hasPrefix("+") { return (false, String(text.dropFirst())) }
        return (false, text)
    }

    func parseHexInteger(_ text: String) -> Int? {
        let (negative, str) = stripSign(text)
        guard str.hasPrefix("0x") || str.hasPrefix("0X") else { return nil }
        return parseMagnitude(str.dropFirst(2), radix: 16, negative: negative)
    }

    func parseBinaryInteger(_ text: String) -> Int? {
        let (negative, str) = stripSign(text)
        guard str.hasPrefix("0b") else { return nil }
        return parseMagnitude(str.dropFirst(2), radix: 2, negative: negative)
    }

    func parseOctalInteger(_ text: String) -> Int? {
        let (negative, str) = stripSign(text)
        guard str.hasPrefix("0o") else { return nil }
        return parseMagnitude(str.dropFirst(2), radix: 8, negative: negative)
    }

    func parseClojureRadixInteger(_ text: String) -> Int? {
        let (negative, rest) = stripSign(text)
        guard let rIdx = rest.firstIndex(where: { $0 == "r" || $0 == "R" }) else { return nil }
        let radixStr = String(rest[rest.startIndex..<rIdx])
        let digits = rest[rest.index(after: rIdx)...]
        guard let radix = Int(radixStr), radix >= 2, radix <= 36, !digits.isEmpty else { return nil }
        return parseMagnitude(digits, radix: radix, negative: negative)
    }

    func parseClojureRadixBigInteger(_ text: String) -> BigInt? {
        let (negative, rest) = stripSign(text)
        guard let rIdx = rest.firstIndex(where: { $0 == "r" || $0 == "R" }) else { return nil }
        let radixStr = String(rest[rest.startIndex..<rIdx])
        let digits = String(rest[rest.index(after: rIdx)...])
        guard let radix = Int(radixStr), radix >= 2, radix <= 36, !digits.isEmpty else { return nil }
        let bigRadix = BigInt(radix)
        var result = BigInt(0)
        for char in digits.uppercased() {
            guard let v = clojureDigitValue(char, radix: radix) else { return nil }
            result = result * bigRadix + BigInt(v)
        }
        return negative ? -result : result
    }

    func clojureDigitValue(_ char: Character, radix: Int) -> Int? {
        let scalar = char.unicodeScalars.first!.value
        let value: Int
        if scalar >= 48 && scalar <= 57 {       // '0'–'9'
            value = Int(scalar - 48)
        } else if scalar >= 65 && scalar <= 90 { // 'A'–'Z'
            value = Int(scalar - 55)
        } else {
            return nil
        }
        return value < radix ? value : nil
    }

    // Parse an unsigned magnitude and apply sign, handling Int.min correctly.
    func parseMagnitude(_ digits: Substring, radix: Int, negative: Bool) -> Int? {
        if negative {
            guard let mag = UInt(digits, radix: radix) else { return nil }
            let minMag = UInt(bitPattern: Int.min)  // 0x8000000000000000
            if mag == minMag { return Int.min }
            guard mag < minMag else { return nil }
            return -Int(mag)
        } else {
            return Int(digits, radix: radix)
        }
    }
}
