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
    let printer = Printer()

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
            let mainPrompt = "λ(\(inputCount))> "
            let continuationPrompt = String(repeating: " ", count: mainPrompt.count - 2) + ". "
            print(mainPrompt, terminator: "")
            guard var input = readLine() else {
                print(defaultCursor, terminator: "")
                print()
                break
            }

            // Handle multiline input
            var contType = continuationNeeded(input)
            while contType != .none {
                print(continuationPrompt, terminator: "")
                guard let continuation = readLine() else {
                    break
                }
                input += (contType == .multilineString ? "\n" : "") + continuation
                contType = continuationNeeded(input)
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
            let processed = substituteResultReferences(trimmed, results: results)
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
        let mainPrompt = "λ(\(inputCount))> "
        let continuationPrompt = String(repeating: " ", count: mainPrompt.count - 2) + ". "

        var input: String
        do {
            input = try ln.readLine(prompt: mainPrompt, strippingNewline: true)
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

        // Handle multiline input
        var contType = continuationNeeded(input)
        while contType != .none {
            do {
                let continuation = try ln.readLine(prompt: continuationPrompt, strippingNewline: true)
                input += (contType == .multilineString ? "\n" : "") + continuation
                contType = continuationNeeded(input)
            }
            catch LineReaderError.EOF {
                break
            }
            catch LineReaderError.CTRLC {
                break
            }
            catch {
                break
            }
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

        // Replace /n references with previous results (but not within ratios)
        let processed = substituteResultReferences(trimmed, results: results)

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

/// Type of continuation needed for incomplete input
private enum ContinuationType {
    case none
    case regularString      // Join without newline
    case multilineString    // Join with newline
}

/// Checks if the input contains an unclosed string literal (regular or multiline).
/// Returns the type of continuation needed.
private func continuationNeeded(_ input: String) -> ContinuationType {
    var i = input.startIndex

    while i < input.endIndex {
        let char = input[i]

        // Check for string opening: " or """
        if char == "\"" {
            let next1 = input.index(i, offsetBy: 1, limitedBy: input.endIndex)
            let next2 = input.index(i, offsetBy: 2, limitedBy: input.endIndex)

            if let n1 = next1, let n2 = next2, n1 < input.endIndex, n2 < input.endIndex,
               input[n1] == "\"", input[n2] == "\"" {
                // Found opening """, now look for closing """
                i = input.index(after: n2)  // Move past opening """

                // Skip optional whitespace and require newline
                while i < input.endIndex && input[i] != "\n" && input[i].isWhitespace {
                    i = input.index(after: i)
                }

                // If no newline found, this might be invalid but let the lexer handle it
                if i >= input.endIndex {
                    return .multilineString  // Unclosed multiline string
                }

                if input[i] == "\n" {
                    i = input.index(after: i)  // Move past newline
                }

                // Now look for closing """
                var foundClosing = false
                while i < input.endIndex {
                    if input[i] == "\"" {
                        let cn1 = input.index(i, offsetBy: 1, limitedBy: input.endIndex)
                        let cn2 = input.index(i, offsetBy: 2, limitedBy: input.endIndex)

                        if let c1 = cn1, let c2 = cn2, c1 < input.endIndex, c2 < input.endIndex,
                           input[c1] == "\"", input[c2] == "\"" {
                            // Found closing """, move past it and continue checking rest of input
                            i = input.index(after: c2)
                            foundClosing = true
                            break
                        }
                    }
                    i = input.index(after: i)
                }

                // If we didn't find closing """, need more input
                if !foundClosing {
                    return .multilineString
                }
                continue
            }
            else {
                // Regular string - look for closing quote
                i = input.index(after: i)
                var foundClosing = false
                while i < input.endIndex {
                    if input[i] == "\\" {
                        // Skip escaped character
                        i = input.index(after: i)
                        if i < input.endIndex {
                            i = input.index(after: i)
                        }
                    }
                    else if input[i] == "\"" {
                        // Found closing quote
                        i = input.index(after: i)
                        foundClosing = true
                        break
                    }
                    else {
                        i = input.index(after: i)
                    }
                }
                // If we didn't find closing quote, need more input
                if !foundClosing {
                    return .regularString
                }
                continue
            }
        }

        i = input.index(after: i)
    }

    return .none
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
        String(value)

    case .float(let value):
        String(value)

    case .ratio(let ratio):
        "\(ratio.numerator)/\(ratio.denominator)"

    case .string(let value):
        "\"\(escapeStringForSource(value))\""

    case .character(let char):
        characterSourceForm(char)

    case .boolean(let value):
        value ? "true" : "false"

    case .nil:
        "nil"
    }
}

/// Converts a Character to source form for substitution
private func characterSourceForm(_ char: Character) -> String {
    switch char {
    case "\n": return "\\newline"
    case "\t": return "\\tab"
    case " ": return "\\space"
    case "\r": return "\\return"
    case "\u{0008}": return "\\backspace"
    case "\u{000C}": return "\\formfeed"
    default: return "\\\(char)"
    }
}

/// Escapes special characters in a string for source code representation
private func escapeStringForSource(_ s: String) -> String {
    var result = ""
    for char in s {
        switch char {
        case "\"": result.append("\\\"")
        case "\\": result.append("\\\\")
        case "\n": result.append("\\n")
        case "\t": result.append("\\t")
        case "\r": result.append("\\r")
        case "\0": result.append("\\0")
        default: result.append(char)
        }
    }
    return result
}

/// Substitutes /n references with previous results, avoiding ratio literals
private func substituteResultReferences(_ input: String, results: [Int: Expr]) -> String {
    var processed = input
    let pattern = /\/(\d+)/
    for match in input.matches(of: pattern) {
        // Skip if preceded by digit or underscore (part of a ratio)
        let matchStart = match.range.lowerBound
        if matchStart > input.startIndex {
            let prevIndex = input.index(before: matchStart)
            let prevChar = input[prevIndex]
            if prevChar.isNumber || prevChar == "_" {
                continue
            }
        }
        if let n = Int(match.1), let previousResult = results[n] {
            processed = processed.replacingOccurrences(of: String(match.0), with: sourceForm(previousResult))
        }
    }
    return processed
}

main()
