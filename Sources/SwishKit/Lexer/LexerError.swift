/// Errors thrown during lexical analysis
public enum LexerError: Error, Equatable, CustomStringConvertible {
    case illegalCharacter(Character, line: Int, column: Int)
    case invalidNumberFormat(String, line: Int, column: Int)
    case invalidRatio(String, line: Int, column: Int)
    case unterminatedString(line: Int, column: Int)
    case invalidEscapeSequence(char: Character, line: Int, column: Int)
    case invalidUnicodeEscape(String, line: Int, column: Int)
    case multilineStringContentOnOpeningLine(line: Int, column: Int)
    case multilineStringInsufficientIndentation(line: Int, column: Int)
    case unterminatedMultilineString(line: Int, column: Int)
    case invalidCharacterLiteral(String, line: Int, column: Int)
    case unknownNamedCharacter(String, line: Int, column: Int)
    case invalidKeyword(String, line: Int, column: Int)
    case unsupportedAutoResolvedKeyword(line: Int, column: Int)

    public var description: String {
        switch self {
        case .illegalCharacter(let char, let line, let column):
            "Illegal character '\(char)' (line \(line), column \(column))."

        case .invalidNumberFormat(let text, let line, let column):
            "Invalid number format '\(text)' (line \(line), column \(column))."

        case .invalidRatio(let text, let line, let column):
            "Invalid ratio '\(text)': division by zero (line \(line), column \(column))."

        case .unterminatedString(let line, let column):
            "Unterminated string (line \(line), column \(column))."

        case .invalidEscapeSequence(let char, let line, let column):
            "Invalid escape sequence '\\(\(char))' (line \(line), column \(column))."

        case .invalidUnicodeEscape(let reason, let line, let column):
            "Invalid Unicode escape: \(reason) (line \(line), column \(column))."

        case .multilineStringContentOnOpeningLine(let line, let column):
            "Multiline string literal must begin with a newline after opening delimiter (line \(line), column \(column))."

        case .multilineStringInsufficientIndentation(let line, let column):
            "Insufficient indentation in multiline string literal (line \(line), column \(column))."

        case .unterminatedMultilineString(let line, let column):
            "Unterminated multiline string literal (line \(line), column \(column))."

        case .invalidCharacterLiteral(let reason, let line, let column):
            "Invalid character literal: \(reason) (line \(line), column \(column))."

        case .unknownNamedCharacter(let name, let line, let column):
            "Unknown named character '\\(\(name))' (line \(line), column \(column))."

        case .invalidKeyword(let reason, let line, let column):
            "Invalid keyword: \(reason) (line \(line), column \(column))."

        case .unsupportedAutoResolvedKeyword(let line, let column):
            "Auto-resolved keywords (::) are not yet supported (line \(line), column \(column))."
        }
    }
}
