import SwishKit
import CommandLineKit
import Foundation

// MARK: - ANSI escape sequences

private let blinkingBarCursor = "\u{1b}[5 q"
private let defaultCursor = "\u{1b}[0 q"

// MARK: - ANSI color codes

private let orange = "\u{1b}[38;2;255;149;0m"      // #FF9500 - Swift logo orange
private let green  = "\u{1b}[38;2;52;199;89m"       // #34C759 - Apple system green
private let reset  = "\u{1b}[0m"

// MARK: - REPL commands

private let commands: [(name: String, description: String)] = [
    ("help", "Show this help message"),
    ("quit", "Exit the REPL"),
    ("<n>", "Reference result n (e.g., /1, /2)")
]

// MARK: - Repl

final class Repl {
    private let swish = Swish()
    private let printer = Printer()
    private var inputCount = 1
    private var results: [Int: Expr] = [:]
    private let lineReader: LineReader?

    init() {
        lineReader = LineReader()
    }

    func run() {
        setupCursor()
        printBanner()
        print("v0.1.0 — Type /help for commands.\n")

        while true {
            let prompt = "λ(\(inputCount))> "
            guard var input = readline(prompt: prompt) else {
                teardownCursor()
                return
            }
            input = readMultilineInput(initial: input, mainPrompt: prompt)
            let trimmed = input.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            lineReader?.addHistory(input)
            switch handleCommand(trimmed) {
            case .exit:        teardownCursor(); return
            case .handled:     continue
            case .notACommand: break
            }
            do {
                let result = try eval(trimmed)
                printResult(result)
            }
            catch {
                printError(error)
            }
            inputCount += 1
        }
    }

    // MARK: - I/O

    private func readline(prompt: String) -> String? {
        if let ln = lineReader {
            do {
                return try ln.readLine(prompt: prompt, strippingNewline: true)
            }
            catch {
                return nil
            }
        }
        else {
            print(prompt, terminator: "")
            return Swift.readLine()
        }
    }

    private func readMultilineInput(initial: String, mainPrompt: String) -> String {
        var input = initial
        var contType = continuationNeeded(input)
        while contType != .none {
            let additional = computeIndent(input, mainPromptLen: mainPrompt.count)
            let continuationPrompt = String(repeating: " ", count: mainPrompt.count - 2) + ". "
                + String(repeating: " ", count: additional)
            guard let continuation = readline(prompt: continuationPrompt) else { break }
            input += "\n" + continuation
            contType = continuationNeeded(input)
        }
        return input
    }

    // MARK: - Command handling

    private enum CommandResult { case exit, handled, notACommand }

    private func handleCommand(_ trimmed: String) -> CommandResult {
        if matchCommand(trimmed, "quit") { return .exit }
        if matchCommand(trimmed, "help") { printHelp(); return .handled }
        return .notACommand
    }

    // MARK: - Eval / print

    private func eval(_ input: String) throws -> Expr {
        let processed = substituteResultReferences(input)
        let result = try swish.eval(processed)
        results[inputCount] = result
        return result
    }

    private func printResult(_ result: Expr) {
        print("\(green)=>\(reset) \(printer.printString(result))\n")
    }

    private func printError(_ error: Error) {
        print("❌ \(error)\n")
    }

    // MARK: - Cursor

    private func setupCursor() {
        print(blinkingBarCursor, terminator: "")
        fflush(stdout)
    }

    private func teardownCursor() {
        print(defaultCursor, terminator: "")
        print()
    }

    // MARK: - Banner / help

    private func printBanner() {
        print("\(orange))λ( Swish\(reset)")
    }

    private func printHelp() {
        print("Commands:")
        for cmd in commands {
            print("  /\(cmd.name) - \(cmd.description)")
        }
        print()
    }

    private func matchCommand(_ input: String, _ command: String) -> Bool {
        guard input.hasPrefix("/") else { return false }
        let typed = String(input.dropFirst())
        return !typed.isEmpty && command.hasPrefix(typed)
    }

    // MARK: - Result substitution

    private func substituteResultReferences(_ input: String) -> String {
        var processed = input
        let pattern = /\/(\d+)/
        for match in input.matches(of: pattern) {
            let matchStart = match.range.lowerBound
            if matchStart > input.startIndex {
                let prevIndex = input.index(before: matchStart)
                let prevChar = input[prevIndex]
                if prevChar.isNumber || prevChar == "_" { continue }
            }
            if let n = Int(match.1), let previousResult = results[n] {
                processed = processed.replacingOccurrences(of: String(match.0), with: printer.sourceForm(previousResult))
            }
        }
        return processed
    }

    // MARK: - String scanning helpers

    // Advances past the closing ", tracking column position. Opening quote already consumed.
    // Returns (newIndex, newCol).
    private func skipRegularStringTrackingCol(from i: String.Index, in s: String, col: Int) -> (String.Index, Int) {
        var j = i
        var col = col
        while j < s.endIndex {
            if s[j] == "\\" {
                j = s.index(after: j)
                if j < s.endIndex { j = s.index(after: j); col += 2 }
            }
            else if s[j] == "\"" {
                j = s.index(after: j); col += 1; break
            }
            else {
                j = s.index(after: j); col += 1
            }
        }
        return (j, col)
    }

    private func isTripleQuote(at i: String.Index, in s: String) -> Bool {
        guard let n1 = s.index(i, offsetBy: 1, limitedBy: s.endIndex),
              let n2 = s.index(i, offsetBy: 2, limitedBy: s.endIndex),
              n1 < s.endIndex, n2 < s.endIndex else { return false }
        return s[n1] == "\"" && s[n2] == "\""
    }

    private func skipPastClosingTripleQuote(from i: String.Index, in s: String) -> (String.Index, Bool) {
        var j = i
        while j < s.endIndex {
            if s[j] == "\"" && isTripleQuote(at: j, in: s) {
                return (s.index(j, offsetBy: 3), true)
            }
            j = s.index(after: j)
        }
        return (j, false)
    }

    private func skipPastClosingQuote(from i: String.Index, in s: String) -> (String.Index, Bool) {
        var j = i
        while j < s.endIndex {
            if s[j] == "\\" {
                j = s.index(after: j)
                if j < s.endIndex { j = s.index(after: j) }
            }
            else if s[j] == "\"" {
                return (s.index(after: j), true)
            }
            else {
                j = s.index(after: j)
            }
        }
        return (j, false)
    }

    // MARK: - Continuation detection

    private enum ContinuationType {
        case none
        case regularString
        case multilineString
        case list
    }

    private func continuationNeeded(_ input: String) -> ContinuationType {
        var i = input.startIndex
        var parenDepth = 0

        while i < input.endIndex {
            switch input[i] {
            case "(", "[": parenDepth += 1
            case ")", "]": parenDepth -= 1
            case "\"":
                if isTripleQuote(at: i, in: input) {
                    i = input.index(i, offsetBy: 3)
                    while i < input.endIndex && input[i] != "\n" && input[i].isWhitespace {
                        i = input.index(after: i)
                    }
                    if i >= input.endIndex { return .multilineString }
                    if input[i] == "\n" { i = input.index(after: i) }
                    let (newI, found) = skipPastClosingTripleQuote(from: i, in: input)
                    i = newI
                    if !found { return .multilineString }
                }
                else {
                    i = input.index(after: i)
                    let (newI, found) = skipPastClosingQuote(from: i, in: input)
                    i = newI
                    if !found { return .regularString }
                }
                continue
            default: break
            }
            i = input.index(after: i)
        }

        return parenDepth > 0 ? .list : .none
    }

    // MARK: - Indent computation

    private func computeIndent(_ input: String, mainPromptLen: Int) -> Int {
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
                } else {
                    (i, col) = skipRegularStringTrackingCol(from: input.index(after: i), in: input, col: col + 1)
                }
                continue
            case "(": stack.append(col + 2)
            case "[": stack.append(col + 1)
            case ")", "]": if !stack.isEmpty { stack.removeLast() }
            default: break
            }
            col += 1
            i = input.index(after: i)
        }

        guard let target = stack.last else { return 0 }
        return max(0, target - mainPromptLen)
    }
}
