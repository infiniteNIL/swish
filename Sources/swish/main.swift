import SwishKit
import Foundation
import CommandLineKit

/// ANSI escape sequences for cursor styling
private let blinkingBarCursor = "\u{1b}[5 q"
private let defaultCursor = "\u{1b}[0 q"

/// ANSI color codes
private let orange = "\u{1b}[38;2;255;149;0m"      // #FF9500 - Swift logo orange
private let green = "\u{1b}[38;2;52;199;89m"      // #34C759 - Apple system green
private let red = "\u{1b}[38;2;255;59;48m"        // #FF3B30 - Apple system red
private let reset = "\u{1b}[0m"

/// REPL commands
private let commands: [(name: String, description: String)] = [
    ("help", "Show this help message"),
    ("quit", "Exit the REPL"),
    ("<n>", "Reference result n (e.g., /1, /2)")
]

/// Swish REPL - Read-Eval-Print Loop
func main() {
    let swish = Swish()
    let printer = Printer(locale: .current)

    // Set blinking bar cursor
    print(blinkingBarCursor, terminator: "")
    fflush(stdout)

    printBanner()
    print("v0.1.0 — Type /help for commands.\n")

    var inputCount = 1
    var results: [Int: Expr] = [:]

    guard let ln = LineReader() else {
        // Fall back to basic readLine if terminal not available
        while true {
            print("λ(\(inputCount))> ", terminator: "")
            guard let input = readLine() else {
                print(defaultCursor, terminator: "")
                print()
                break
            }
            let trimmed = input.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if matchCommand(trimmed, "quit") {
                print(defaultCursor, terminator: "")
                break
            }
            if matchCommand(trimmed, "help") {
                printHelp()
                continue
            }
            var processed = trimmed
            let pattern = /\/(\d+)/
            for match in trimmed.matches(of: pattern) {
                if let n = Int(match.1), let previousResult = results[n] {
                    processed = processed.replacingOccurrences(of: String(match.0), with: sourceForm(previousResult))
                }
            }
            do {
                let result = try swish.eval(processed)
                results[inputCount] = result
                print("\(green)=>\(reset) \(printer.printString(result))\n")
            }
            catch {
                print("❌ \(error)\n")
            }
            inputCount += 1
        }
        return
    }

    while true {
        let input: String
        do {
            input = try ln.readLine(prompt: "λ(\(inputCount))> ", strippingNewline: true)
        }
        catch LineReaderError.EOF {
            print(defaultCursor, terminator: "")
            print()
            break
        }
        catch LineReaderError.CTRLC {
            print(defaultCursor, terminator: "")
            print()
            break
        }
        catch {
            print(defaultCursor, terminator: "")
            print("Error: \(error)")
            break
        }

        let trimmed = input.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            continue
        }

        ln.addHistory(input)

        if matchCommand(trimmed, "quit") {
            print(defaultCursor, terminator: "")
            break
        }

        if matchCommand(trimmed, "help") {
            printHelp()
            continue
        }

        // Replace /n references with previous results
        var processed = trimmed
        let pattern = /\/(\d+)/
        for match in trimmed.matches(of: pattern) {
            if let n = Int(match.1), let previousResult = results[n] {
                processed = processed.replacingOccurrences(of: String(match.0), with: sourceForm(previousResult))
            }
        }

        do {
            let result = try swish.eval(processed)
            results[inputCount] = result
            print("\(green)=>\(reset) \(printer.printString(result))\n")
        }
        catch {
            print("❌ \(error)\n")
        }
        inputCount += 1
    }
}

/// Swish logo banner
private func printBanner() {
    print("\(orange))λ( Swish\(reset)")
}

/// Check if input matches a command (prefix matching)
private func matchCommand(_ input: String, _ command: String) -> Bool {
    guard input.hasPrefix("/") else { return false }
    let typed = String(input.dropFirst())
    return !typed.isEmpty && command.hasPrefix(typed)
}

/// Print help message
private func printHelp() {
    print("Commands:")
    for cmd in commands {
        print("  /\(cmd.name) - \(cmd.description)")
    }
    print()
}

/// Converts an Expr to source form for substitution (raw value, not formatted)
private func sourceForm(_ expr: Expr) -> String {
    switch expr {
    case .integer(let value):
        return String(value)
    case .float(let value):
        return String(value)
    }
}

main()
