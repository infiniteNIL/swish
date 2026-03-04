import ArgumentParser
import Foundation
import SwishKit

struct SwishCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swish",
        abstract: "A Clojure-like Lisp for Swift"
    )

    @Argument(help: "A Swish source file to run. If omitted, starts the REPL.")
    var file: String?

    func run() throws {
        if let file {
            guard FileManager.default.fileExists(atPath: file) else {
                fputs("error: file not found: \(file)\n", stderr)
                throw ExitCode.failure
            }
            let interpreter = Swish()
            do {
                try interpreter.run(filename: file)
            } catch {
                fputs("error: \(error)\n", stderr)
                throw ExitCode.failure
            }
        } else {
            startREPL()
        }
    }
}
