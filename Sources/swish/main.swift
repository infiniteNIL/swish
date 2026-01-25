import SwishKit
import Foundation
import CommandLineKit

/// ANSI escape sequences for cursor styling
private let blinkingBarCursor = "\u{1b}[5 q"
private let defaultCursor = "\u{1b}[0 q"

/// ANSI color codes for banner
private let orange = "\u{1b}[38;2;255;149;0m"      // #FF9500 - Swift logo orange
private let reset = "\u{1b}[0m"

/// Swish logo banner
private func printBanner() {
    print("\(orange)🏀 Swish\(reset)")
}

/// Swish REPL - Read-Eval-Print Loop
func main() {
    let swish = Swish()

    // Set blinking bar cursor
    print(blinkingBarCursor, terminator: "")
    fflush(stdout)

    printBanner()
    print("v0.1.0 — Type (exit) to quit.\n")

    var inputCount = 1
    var results: [Int: String] = [:]

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
            if trimmed == "(exit)" || trimmed == "(quit)" {
                print(defaultCursor, terminator: "")
                print("Goodbye!")
                break
            }
            var processed = trimmed
            let pattern = /\*(\d+)/
            for match in trimmed.matches(of: pattern) {
                if let n = Int(match.1), let previousResult = results[n] {
                    processed = processed.replacingOccurrences(of: String(match.0), with: previousResult)
                }
            }
            let result = swish.eval(processed)
            results[inputCount] = result
            print("=> " + result + "\n")
            inputCount += 1
        }
        return
    }

    while true {
        let input: String
        do {
            input = try ln.readLine(prompt: "λ(\(inputCount))> ", strippingNewline: true)
        } catch LineReaderError.EOF {
            print(defaultCursor, terminator: "")
            print()
            break
        } catch LineReaderError.CTRLC {
            print(defaultCursor, terminator: "")
            print()
            break
        } catch {
            print(defaultCursor, terminator: "")
            print("Error: \(error)")
            break
        }

        let trimmed = input.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            continue
        }

        ln.addHistory(input)

        if trimmed == "(exit)" || trimmed == "(quit)" {
            print(defaultCursor, terminator: "")
            print("Goodbye!")
            break
        }

        // Replace *n references with previous results
        var processed = trimmed
        let pattern = /\*(\d+)/
        for match in trimmed.matches(of: pattern) {
            if let n = Int(match.1), let previousResult = results[n] {
                processed = processed.replacingOccurrences(of: String(match.0), with: previousResult)
            }
        }

        let result = swish.eval(processed)
        results[inputCount] = result
        print("=> " + result + "\n")
        inputCount += 1
    }
}

main()
