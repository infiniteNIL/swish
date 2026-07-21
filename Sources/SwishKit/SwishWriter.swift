import Foundation
import Synchronization

public final class SwishWriter: @unchecked Sendable {
    public let path: String?
    private let handle: FileHandle?
    private let closedState = Mutex(false)
    private let buffer = Mutex("")

    var closed: Bool { closedState.withLock { $0 } }

    init(path: String, append: Bool) throws {
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        guard let handle = FileHandle(forWritingAtPath: path) else {
            throw SwishIOError.fileNotWritable(path)
        }
        if append {
            handle.seekToEndOfFile()
        }
        else {
            try handle.truncate(atOffset: 0)
        }
        self.path = path
        self.handle = handle
    }

    /// Creates an in-memory writer whose content can be read back with `bufferedString`.
    init() {
        self.path = nil
        self.handle = nil
    }

    var bufferedString: String { buffer.withLock { $0 } }

    func write(_ s: String) throws {
        try closedState.withLock { closed in
            guard !closed else { throw SwishIOError.writerClosed }
            guard let handle else {
                buffer.withLock { $0 += s }
                return
            }
            guard let data = s.data(using: .utf8) else { return }
            handle.write(data)
        }
    }

    func close() {
        closedState.withLock { closed in
            guard !closed else { return }
            handle?.closeFile()
            closed = true
        }
    }

    deinit {
        if !closed { handle?.closeFile() }
    }
}

enum SwishIOError: Error, LocalizedError {
    case fileNotFound(String)
    case fileNotWritable(String)
    case writerClosed

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let p):   "No such file: \(p)"
        case .fileNotWritable(let p): "Cannot open file for writing: \(p)"
        case .writerClosed:           "Writer is closed"
        }
    }
}
