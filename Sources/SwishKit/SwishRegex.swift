public struct SwishRegex: @unchecked Sendable {
    public let pattern: String
    public let regex: Regex<AnyRegexOutput>

    init(pattern: String) throws {
        self.pattern = pattern
        self.regex = try Regex(pattern)
    }
}

extension SwishRegex: Equatable {
    public static func == (lhs: SwishRegex, rhs: SwishRegex) -> Bool {
        lhs.pattern == rhs.pattern
    }
}

extension SwishRegex: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(pattern)
    }
}
