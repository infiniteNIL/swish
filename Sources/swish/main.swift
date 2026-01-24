import SwishKit
import Foundation
import CommandLineKit

/// Swish REPL - Read-Eval-Print Loop
func main() {
    let swish = Swish()

    print("Swish v0.1.0")
    print("Type (exit) to quit.\n")

    var inputCount = 1
    var results: [Int: String] = [:]

    guard let ln = LineReader() else {
        // Fall back to basic readLine if terminal not available
        while true {
            print("λ(\(inputCount))> ", terminator: "")
            guard let input = readLine() else {
                print()
                break
            }
            let trimmed = input.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed == "(exit)" || trimmed == "(quit)" {
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
            print()
            break
        } catch LineReaderError.CTRLC {
            print()
            continue
        } catch {
            print("Error: \(error)")
            break
        }

        let trimmed = input.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            continue
        }

        ln.addHistory(input)

        if trimmed == "(exit)" || trimmed == "(quit)" {
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
