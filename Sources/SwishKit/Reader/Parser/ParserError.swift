public enum ParserError: Error, Equatable, CustomStringConvertible {
    case unexpectedToken(Token)
    case unexpectedEOF
    case integerOverflow(String)
    case invalidFloat(String)
    case unterminatedList(line: Int, column: Int)
    case unterminatedVector(line: Int, column: Int)
    case invalidDef(String)
    case invalidLet(String)
    case invalidFn(String)
    case invalidDefmacro(String)

    public var description: String {
        switch self {
        case .unexpectedToken(let token):
            "Unexpected token '\(token.text)' (line \(token.line), column \(token.column))."

        case .unexpectedEOF:
            "Unexpected end of input."

        case .integerOverflow(let text):
            "Integer overflow: '\(text)' is too large."

        case .invalidFloat(let text):
            "Invalid float: '\(text)'."

        case .unterminatedList(let line, let column):
            "Unterminated list (line \(line), column \(column))."

        case .unterminatedVector(let line, let column):
            "Unterminated vector (line \(line), column \(column))."

        case .invalidDef(let message):
            message

        case .invalidLet(let message):
            message

        case .invalidFn(let message):
            message

        case .invalidDefmacro(let message):
            message
        }
    }
}
