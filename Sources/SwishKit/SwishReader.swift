import Foundation

public final class SwishReader: @unchecked Sendable {
    public let path: String
    private let handle: FileHandle
    private var buffer: Data = Data()
    private var eof: Bool = false
    private(set) var closed: Bool = false

    init(path: String) throws {
        guard let handle = FileHandle(forReadingAtPath: path) else {
            throw SwishIOError.fileNotFound(path)
        }
        self.path = path
        self.handle = handle
    }

    func readLine() -> String? {
        guard !closed else { return nil }
        let newlineByte = UInt8(ascii: "\n")

        while true {
            if let idx = buffer.firstIndex(of: newlineByte) {
                let lineData = buffer[buffer.startIndex..<idx]
                buffer = Data(buffer[buffer.index(after: idx)...])
                var line = String(data: lineData, encoding: .utf8) ?? ""
                if line.hasSuffix("\r") { line.removeLast() }
                return line
            }

            if eof { break }

            let chunk = handle.readData(ofLength: 4096)
            if chunk.isEmpty {
                eof = true
            }
            else {
                buffer.append(chunk)
            }
        }

        if !buffer.isEmpty {
            let lineData = buffer
            buffer = Data()
            var line = String(data: lineData, encoding: .utf8) ?? ""
            if line.hasSuffix("\r") { line.removeLast() }
            return line
        }

        return nil
    }

    func close() {
        guard !closed else { return }
        handle.closeFile()
        closed = true
    }

    deinit {
        if !closed { handle.closeFile() }
    }
}
