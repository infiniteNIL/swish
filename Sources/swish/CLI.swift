import ArgumentParser
import Foundation
import SwishKit

@main
struct SwishCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swish",
        abstract: "Swish: A Clojure-like Lisp for Swift"
    )

    @Option(name: [.customLong("sp", withSingleDash: true), .long],
            help: "Colon-separated list of source directories to search for namespaces.")
    var sourcepath: String?

    @Argument(help: "A Swish source file to run. If omitted, starts the REPL.")
    var file: String?

    func run() throws {
        let sourcePaths = sourcepath.map { $0.split(separator: ":").map(String.init) } ?? []
        if let file {
            guard FileManager.default.fileExists(atPath: file) else {
                fputs("error: file not found: \(file)\n", stderr)
                throw ExitCode.failure
            }
            let interpreter = Swish(sourcePaths: sourcePaths)
            do {
                try interpreter.run(filename: file)
            }
            catch {
                fputs("error: \(error)\n", stderr)
                throw ExitCode.failure
            }
        }
        else {
            Repl(sourcePaths: sourcePaths).run()
        }
    }
}
