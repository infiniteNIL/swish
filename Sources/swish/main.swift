import SwishKit
import Foundation

/// Swish REPL - Read-Eval-Print Loop
func main() {
    let swish = Swish()

    print("Swish v0.1.0")
    print("Type (exit) to quit.\n")

    var inputCount = 1
    var results: [Int: String] = [:]

    while true {
        print("λ(\(inputCount))> ", terminator: "")

        guard let input = readLine() else {
            print()
            break
        }

        let trimmed = input.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            continue
        }

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
