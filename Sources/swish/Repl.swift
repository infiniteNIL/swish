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
    private var inputCancelled = false

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
            guard var input = readline(prompt: prompt) else {
                if inputCancelled {
                    inputCancelled = false
                    continue
                }
                teardownCursor()
                return
            }

            input = readMultilineInput(initial: input, mainPrompt: prompt)
            if inputCancelled {
                inputCancelled = false
                continue
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

    private func readline(prompt: String) -> String? {
        if let ln = lineReader {
            do {
                return try ln.readLine(prompt: prompt, strippingNewline: true)
            }
            catch LineReaderError.CTRLC {
                print("^C")
                inputCancelled = true
                return nil
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
        while true {
            let contType = continuationNeeded(input)
            if contType == .none && !isIncompleteByParsing(input) { break }
            let additional = computeIndent(input, mainPromptLen: mainPrompt.count)
            let continuationPrompt = String(repeating: " ", count: mainPrompt.count - 2) + ". "
                + String(repeating: " ", count: additional)
            guard let continuation = readline(prompt: continuationPrompt) else { break }
            input += "\n" + continuation
        }
        return input
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
                if prevChar.isNumber || prevChar == "_" {
                    continue
                }
            }
            if let n = Int(match.1), let previousResult = results[n] {
                processed = processed.replacingOccurrences(of: String(match.0), with: printer.sourceForm(previousResult))
            }
        }
        return processed
    }

}
