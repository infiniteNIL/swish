import Foundation

extension Repl {

    enum ContinuationType {
        case none
        case regularString
        case multilineString
        case form
    }

    // MARK: - String scanning helpers

    // Escape-aware scan past a string body, optionally tracking column position.
    // Opening quote already consumed. `col` is `nil` when the caller only cares
    // about the resulting index and whether a closing quote was found.
    private func skipStringBody(from i: String.Index, in s: String, col: Int?) -> (index: String.Index, col: Int?, found: Bool) {
        var j = i
        var col = col
        while j < s.endIndex {
            if s[j] == "\\" {
                j = s.index(after: j)
                if j < s.endIndex {
                    j = s.index(after: j)
                    col = col.map { $0 + 2 }
                }
            }
            else if s[j] == "\"" {
                j = s.index(after: j)
                col = col.map { $0 + 1 }
                return (j, col, true)
            }
            else {
                j = s.index(after: j)
                col = col.map { $0 + 1 }
            }
        }
        return (j, col, false)
    }

    // Advances past the closing ", tracking column position. Opening quote already consumed.
    // Returns (newIndex, newCol).
    func skipRegularStringTrackingCol(from i: String.Index, in s: String, col: Int) -> (String.Index, Int) {
        let (j, newCol, _) = skipStringBody(from: i, in: s, col: col)
        return (j, newCol ?? col)
    }

    func isTripleQuote(at i: String.Index, in s: String) -> Bool {
        guard let n1 = s.index(i, offsetBy: 1, limitedBy: s.endIndex),
              let n2 = s.index(i, offsetBy: 2, limitedBy: s.endIndex),
              n1 < s.endIndex, n2 < s.endIndex else { return false }
        return s[n1] == "\"" && s[n2] == "\""
    }

    func skipPastClosingTripleQuote(from i: String.Index, in s: String) -> (String.Index, Bool) {
        var j = i
        while j < s.endIndex {
            if s[j] == "\"" && isTripleQuote(at: j, in: s) {
                return (s.index(j, offsetBy: 3), true)
            }
            j = s.index(after: j)
        }
        return (j, false)
    }

    func skipPastClosingQuote(from i: String.Index, in s: String) -> (String.Index, Bool) {
        let (j, _, found) = skipStringBody(from: i, in: s, col: nil)
        return (j, found)
    }

    // MARK: - Continuation detection

    func continuationNeeded(_ input: String) -> ContinuationType {
        var i = input.startIndex
        var parenDepth = 0

        while i < input.endIndex {
            switch input[i] {
            case "(", "[", "{":
                parenDepth += 1

            case ")", "]", "}":
                parenDepth -= 1

            case "\"":
                if isTripleQuote(at: i, in: input) {
                    i = input.index(i, offsetBy: 3)
                    while i < input.endIndex && input[i] != "\n" && input[i].isWhitespace {
                        i = input.index(after: i)
                    }
                    if i >= input.endIndex {
                        return .multilineString
                    }
                    if input[i] == "\n" {
                        i = input.index(after: i)
                    }
                    let (newI, found) = skipPastClosingTripleQuote(from: i, in: input)
                    i = newI
                    if !found {
                        return .multilineString
                    }
                }
                else {
                    i = input.index(after: i)
                    let (newI, found) = skipPastClosingQuote(from: i, in: input)
                    i = newI
                    if !found {
                        return .regularString
                    }
                }
                continue

            default:
                break
            }
            i = input.index(after: i)
        }

        return parenDepth > 0 ? .form : .none
    }

    // MARK: - Indent computation

    func computeIndent(_ input: String, mainPromptLen: Int) -> Int {
        var col = mainPromptLen
        var stack: [Int] = []
        var i = input.startIndex

        while i < input.endIndex {
            switch input[i] {
            case "\n":
                col = stack.last ?? mainPromptLen
                i = input.index(after: i)
                continue

            case "\"":
                if isTripleQuote(at: i, in: input) {
                    i = input.index(i, offsetBy: 3)
                    (i, _) = skipPastClosingTripleQuote(from: i, in: input)
                }
                else {
                    (i, col) = skipRegularStringTrackingCol(from: input.index(after: i), in: input, col: col + 1)
                }
                continue

            case "(":
                stack.append(col + 2)

            case "[", "{":
                stack.append(col + 1)

            case ")", "]", "}":
                if !stack.isEmpty {
                    stack.removeLast()
                }

            default:
                break
            }
            col += 1
            i = input.index(after: i)
        }

        guard let target = stack.last else { return 0 }
        return max(0, target - mainPromptLen)
    }
}
