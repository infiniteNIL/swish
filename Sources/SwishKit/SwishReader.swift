import Foundation
import Synchronization

public final class SwishReader: @unchecked Sendable {
    public let path: String
    private let handle: FileHandle

    private struct State {
        var buffer = Data()
        var eof = false
        var closed = false
    }
    private let state = Mutex(State())

    var closed: Bool { state.withLock { $0.closed } }

    init(path: String) throws {
        guard let handle = FileHandle(forReadingAtPath: path) else {
            throw SwishIOError.fileNotFound(path)
        }
        self.path = path
        self.handle = handle
    }

    func readLine() -> String? {
        state.withLock { s in
            guard !s.closed else { return nil }
            let newlineByte = UInt8(ascii: "\n")

            while true {
                if let idx = s.buffer.firstIndex(of: newlineByte) {
                    let lineData = s.buffer[s.buffer.startIndex..<idx]
                    s.buffer = Data(s.buffer[s.buffer.index(after: idx)...])
                    var line = String(data: lineData, encoding: .utf8) ?? ""
                    if line.hasSuffix("\r") { line.removeLast() }
                    return line
                }

                if s.eof { break }

                let chunk = handle.readData(ofLength: 4096)
                if chunk.isEmpty {
                    s.eof = true
                }
                else {
                    s.buffer.append(chunk)
                }
            }

            if !s.buffer.isEmpty {
                let lineData = s.buffer
                s.buffer = Data()
                var line = String(data: lineData, encoding: .utf8) ?? ""
                if line.hasSuffix("\r") { line.removeLast() }
                return line
            }

            return nil
        }
    }

    func close() {
        state.withLock { s in
            guard !s.closed else { return }
            handle.closeFile()
            s.closed = true
        }
    }

    deinit {
        if !closed { handle.closeFile() }
    }
}
