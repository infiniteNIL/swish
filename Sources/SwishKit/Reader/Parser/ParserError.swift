public enum ParserError: Error, Equatable, CustomStringConvertible {
    case unexpectedToken(Token)
    case unexpectedEOF
    case integerOverflow(String)
    case invalidFloat(String)
    case unterminatedList(line: Int, column: Int)
    case unterminatedVector(line: Int, column: Int)
    case unterminatedMap(line: Int, column: Int)
    case oddNumberOfMapForms(line: Int, column: Int)
    case unterminatedSet(line: Int, column: Int)
    case duplicateSetElement(String, line: Int, column: Int)
    case invalidMetadataSpec(line: Int, column: Int)
    case metadataOnUnsupportedForm(line: Int, column: Int)
    case invalidDef(String)
    case invalidLet(String)
    case invalidFn(String)
    case invalidDefmacro(String)
    case invalidLoop(String)
    case invalidThrow(String)

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

        case .unterminatedMap(let line, let column):
            "Unterminated map (line \(line), column \(column))."

        case .oddNumberOfMapForms(let line, let column):
            "Map literal (line \(line), column \(column)) requires an even number of forms."

        case .unterminatedSet(let line, let column):
            "Unterminated set (line \(line), column \(column))."

        case .duplicateSetElement(let key, let line, let column):
            "Duplicate key: \(key) (set literal at line \(line), column \(column))."

        case .invalidMetadataSpec(let line, let column):
            "Invalid metadata spec (line \(line), column \(column)): must be a keyword, symbol, string, or map."

        case .metadataOnUnsupportedForm(let line, let column):
            "Metadata (line \(line), column \(column)) cannot be attached to this form."

        case .invalidDef(let message):
            message

        case .invalidLet(let message):
            message

        case .invalidFn(let message):
            message

        case .invalidDefmacro(let message):
            message

        case .invalidLoop(let message):
            message

        case .invalidThrow(let message):
            message
        }
    }
}
