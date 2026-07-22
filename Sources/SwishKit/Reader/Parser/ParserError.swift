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
    case duplicateMapKey(String, line: Int, column: Int)
    case invalidMetadataSpec(line: Int, column: Int)
    case metadataOnUnsupportedForm(line: Int, column: Int)
    case invalidDef(String, line: Int, column: Int)
    case invalidLet(String, line: Int, column: Int)
    case invalidFn(String, line: Int, column: Int)
    case invalidDefmacro(String, line: Int, column: Int)
    case invalidLoop(String, line: Int, column: Int)
    case invalidThrow(String, line: Int, column: Int)
    case nestedAnonymousFunction(line: Int, column: Int)
    case invalidReaderConditional(String, line: Int, column: Int)
    case splicingOutsideCollection(line: Int, column: Int)
    case invalidTaggedLiteral(String, line: Int, column: Int)
    case unknownTaggedLiteral(tag: String, value: Expr, line: Int, column: Int)

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

        case .duplicateMapKey(let key, let line, let column):
            "Map literal contains duplicate key: \(key) (line \(line), column \(column))."

        case .invalidMetadataSpec(let line, let column):
            "Invalid metadata spec (line \(line), column \(column)): must be a keyword, symbol, string, or map."

        case .metadataOnUnsupportedForm(let line, let column):
            "Metadata (line \(line), column \(column)) cannot be attached to this form."

        case .invalidDef(let message, let line, let column):
            "\(message) (line \(line), column \(column))."

        case .invalidLet(let message, let line, let column):
            "\(message) (line \(line), column \(column))."

        case .invalidFn(let message, let line, let column):
            "\(message) (line \(line), column \(column))."

        case .invalidDefmacro(let message, let line, let column):
            "\(message) (line \(line), column \(column))."

        case .invalidLoop(let message, let line, let column):
            "\(message) (line \(line), column \(column))."

        case .invalidThrow(let message, let line, let column):
            "\(message) (line \(line), column \(column))."

        case .nestedAnonymousFunction(let line, let column):
            "Anonymous function literals cannot be nested (line \(line), column \(column))."

        case .invalidReaderConditional(let message, let line, let column):
            "Invalid reader conditional (line \(line), column \(column)): \(message)."

        case .splicingOutsideCollection(let line, let column):
            "Splicing reader conditional #?@ not allowed outside a collection (line \(line), column \(column))."

        case .invalidTaggedLiteral(let message, let line, let column):
            "Invalid tagged literal (line \(line), column \(column)): \(message)."

        case .unknownTaggedLiteral(let tag, _, let line, let column):
            "No reader function for tag #\(tag) (line \(line), column \(column))."
        }
    }
}
