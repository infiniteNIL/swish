import SwishKit
import Foundation

/// Swish REPL - Read-Eval-Print Loop
func main() {
    let swish = Swish()

    print("Swish Lisp v0.1.0")
    print("Type (exit) to quit.\n")

    while true {
        print("λ> ", terminator: "")

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

        let result = swish.eval(trimmed)
        print(result + "\n")
    }
}

main()
