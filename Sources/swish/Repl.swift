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

// MARK: - Evaluation interrupt flag (file-scope so C-compatible signal handler can write to it)

nonisolated(unsafe) private var sigintReceived: Int32 = 0

// MARK: - Repl

final class Repl {
    private var swish: Swish
    private let printer = Printer()
    private var inputCount = 1
    private var results: [Int: Expr] = [:]
    private let lineReader: LineReader?

    init(sourcePaths: [String] = []) {
        swish = Swish(sourcePaths: sourcePaths)
        lineReader = LineReader()
    }

    func run() {
        setupCursor()
        printBanner()
        print("v0.1.0 — Type /help for commands.\n")

        while true {
            let prompt = "\(swish.currentNamespaceName)(\(inputCount))> "
            // Ctrl-C at an idle prompt exits, the same as end of input. *During* an
            // evaluation it interrupts instead — that's the SIGINT handler below.
            guard case .line(let firstLine) = readline(prompt: prompt) else {
                teardownCursor()
                return
            }

            let input: String
            switch readMultilineInput(initial: firstLine, mainPrompt: prompt) {
            case .line(let complete):
                input = complete

            case .interrupted:
                // Abandons a partly-typed form rather than quitting outright; the next
                // Ctrl-C, now at an empty main prompt, exits.
                continue

            case .endOfInput:
                teardownCursor()
                return
            }

            let trimmed = input.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            lineReader?.addHistory(input)

            switch handleCommand(trimmed) {
            case .exit:
                teardownCursor()
                return

            case .handled:
                continue

            case .notACommand:
                break
            }

            if (try? Reader.readString(trimmed))?.isEmpty == true { continue }

            sigintReceived = 0
            swish.interruptionCheck = { sigintReceived != 0 }
            let prevSigint = signal(SIGINT) { _ in sigintReceived = 1 }
            defer {
                signal(SIGINT, prevSigint)
                sigintReceived = 0
                swish.interruptionCheck = nil
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

    /// Why a line read ended, so the main prompt and a continuation prompt can treat a
    /// cancelled read differently.
    private enum LineResult {
        case line(String)

        /// Ctrl-C. CommandLineKit clears `ISIG` in raw mode, so this arrives as a thrown
        /// error rather than a signal — which is why it's handled here and not by the
        /// `SIGINT` handler that covers a running evaluation.
        case interrupted

        /// End of input, or a reader failure. Also the non-TTY path: `LineReader.init?`
        /// returns nil when stdin isn't a terminal, and `Swift.readLine()` returns nil
        /// at EOF.
        case endOfInput
    }

    private func readline(prompt: String) -> LineResult {
        guard let lineReader else {
            print(prompt, terminator: "")
            guard let line = Swift.readLine() else { return .endOfInput }
            return .line(line)
        }

        do {
            return .line(try lineReader.readLine(prompt: prompt, strippingNewline: true))
        }
        catch LineReaderError.CTRLC {
            print("^C")
            return .interrupted
        }
        catch {
            return .endOfInput
        }
    }

    private func readMultilineInput(initial: String, mainPrompt: String) -> LineResult {
        var input = initial
        while true {
            let contType = continuationNeeded(input)
            if contType == .none && !isIncompleteByParsing(input) {
                return .line(input)
            }
            let additional = computeIndent(input, mainPromptLen: mainPrompt.count)
            let continuationPrompt = String(repeating: " ", count: mainPrompt.count - 2) + ". "
                + String(repeating: " ", count: additional)
            switch readline(prompt: continuationPrompt) {
            case .line(let continuation):
                input += "\n" + continuation

            case .interrupted:
                return .interrupted

            // Previously this returned the partial text, which could only fail to parse.
            case .endOfInput:
                return .endOfInput
            }
        }
    }

    /// Returns true when the pre-scan says depth is balanced but parsing still needs more input —
    /// e.g. `#_form` with nothing following, or a reader macro prefix (`'`, `` ` ``, `~`) at end of input.
    private func isIncompleteByParsing(_ input: String) -> Bool {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        do {
            _ = try Reader.readString(input)
            return false
        }
        catch ParserError.unexpectedEOF {
            return true
        }
        catch {
            return false
        }
    }

    // MARK: - Command handling

    private enum CommandResult { case exit, handled, notACommand }

    private func handleCommand(_ trimmed: String) -> CommandResult {
        if matchCommand(trimmed, "quit") {
            return .exit
        }
        if matchCommand(trimmed, "help") {
            printHelp()
            return .handled
        }
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
        if case EvaluatorError.interrupted = error {
            print("\r\u{1b}[K", terminator: "")
        }
        print("❌ \(swish.describeError(error))\n")
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
        let pattern = /\/(\d+)/
        var result = ""
        var cursor = input.startIndex
        for match in input.matches(of: pattern) {
            let matchStart = match.range.lowerBound
            if matchStart > input.startIndex {
                let prevIndex = input.index(before: matchStart)
                let prevChar = input[prevIndex]
                if prevChar.isNumber || prevChar == "_" {
                    continue
                }
            }
            guard let n = Int(match.1), let previousResult = results[n] else { continue }
            result += input[cursor..<match.range.lowerBound]
            result += printer.sourceForm(previousResult)
            cursor = match.range.upperBound
        }
        result += input[cursor...]
        return result
    }

}
