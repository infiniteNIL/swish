/// Swish - A Clojure-like Lisp for Swift
///
/// SwishKit provides the core Lisp interpreter functionality
/// for embedding in Swift applications.

import Foundation

/// The main entry point for the Swish Lisp interpreter.
public struct Swish: @unchecked Sendable {
    let evaluator: Evaluator
    private let sourcePaths: [String]
    
    /// Init Swish
    /// initialized the Swish interpreter
    ///
    /// - Parameter sourcePaths: the directories to search for swish files
    ///                          (The main bundle and the current directory is automatically added)
    public init(sourcePaths: [String] = []) {
        let envPaths = ProcessInfo.processInfo.environment["SWISH_SOURCEPATH"]
            .map { $0.split(separator: ":").map(String.init) } ?? []

        var paths = envPaths

        // Add SwishKit bundle as well
        if let swishKitPath = Bundle(for: Evaluator.self).resourcePath {
            paths.append(swishKitPath)
        }

        if let bundlePath = Bundle.main.resourcePath {
            paths.append(bundlePath)
        }

        self.sourcePaths = paths + sourcePaths + [FileManager.default.currentDirectoryPath]
        evaluator = Evaluator(sourcePaths: self.sourcePaths)
    }

    public init() {
        self.init(sourcePaths: [])
    }

    /// Reads and evaluates a Swish source file. Will find the file in the sourcePaths
    /// passed to the initializer
    ///
    /// - Parameter filename: Path to the file to run
    /// - Throws: `SwishError` if the file can't be found or read, or if
    ///   evaluating it fails.
    public func load(filename: String) throws {
        do {
            // TODO: What if filename includes path? Then we need to just use it, and not search for it.
            guard let path = findFile(filename) else {
                throw SwishLoadError.fileNotFound(filename, searched: sourcePaths)
            }

            let source = try String(contentsOfFile: path, encoding: .utf8)
            _ = try eval(source)
        }
        catch {
            throw error
        }
    }

    private func findFile(_ filename: String) -> String? {
        // For full paths, just see if it exists
        if filename.starts(with: Self.pathSeparator) {
            if fileExists(filename) {
                return filename
            }
        }

        for path in sourcePaths {
            let filePath = NSString.path(withComponents: [path, filename])
            if fileExists(filePath) {
                return filePath
            }
        }

        return nil
    }

    private func fileExists(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && !isDir.boolValue {
            return true
        }
        else {
            return false
        }
    }

    private static var pathSeparator: String {
        #if os(Windows)
            "\\"
        #else
            "/"
        #endif
    }

    /// Evaluates a Lisp expression string and returns the result.
    /// - Parameter source: A string containing a Lisp expression
    /// - Returns: The evaluated `Expr` value
    /// - Throws: `LexerError`, `ParserError`, or `EvaluatorError` if the input is invalid
    public var currentNamespaceName: String {
        evaluator.currentNamespaceName
    }

    /// Polled during evaluation; return true to interrupt it.
    ///
    /// `nonmutating` because it writes through to the evaluator, which is a
    /// class — without it, a host holding `let swish = Swish()` (which is the
    /// normal shape) couldn't set this at all.
    public var interruptionCheck: (() -> Bool)? {
        get { evaluator.interruptionCheck }
        nonmutating set { evaluator.interruptionCheck = newValue }
    }

    /// Evaluates Swish source and returns the value of its last form.
    ///
    /// - Throws: one of the `SwishError` types — a `LexerError` or
    ///   `ParserError` from reading, an `EvaluatorError` or `NamespaceError`
    ///   from evaluating, or a `SwishException` carrying a value the Swish code
    ///   threw. Catch `any SwishError` to handle them uniformly.
    public func eval(_ source: String) throws -> Expr {
        let exprs = try Reader.readString(source)
        guard !exprs.isEmpty else { throw ParserError.unexpectedEOF }
        var result: Expr = .nil
        for expr in exprs {
            result = try evaluator.eval(expr)
        }
        return result
    }

    /// Renders a value the way `pr-str` does — readably, so strings are quoted.
    public func printString(_ expr: Expr) -> String {
        evaluator.makePrinter().printString(expr)
    }

    /// Renders a value the way `str` does — a bare string stays bare.
    public func toString(_ expr: Expr) -> String {
        evaluator.makePrinter().strString(expr)
    }

    /// Returns a human-readable description of a caught evaluation error, for
    /// display at a top level (REPL, CLI). Routes the underlying thrown value
    /// through the printer instead of Swift's raw struct interpolation.
    public func describeError(_ error: Error) -> String {
        Printer().strString(evaluator.exprForError(error))
    }
}
