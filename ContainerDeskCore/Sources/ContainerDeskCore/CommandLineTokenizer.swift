import Foundation

public enum CommandLineTokenizerError: LocalizedError, Sendable {
    case unterminatedQuote(Character)

    public var errorDescription: String? {
        switch self {
        case .unterminatedQuote(let quote):
            return "Unterminated quoted string (\(quote))."
        }
    }
}

public enum CommandLineTokenizer {
    /// Tokenizes a shell-like command line into argv tokens.
    ///
    /// Supports whitespace splitting, single/double quotes, and `\` escaping.
    public static func tokenize(_ input: String) throws -> [String] {
        var tokens: [String] = []
        var current = ""
        var activeQuote: Character? = nil
        var isEscaping = false

        for ch in input {
            if isEscaping {
                current.append(ch)
                isEscaping = false
                continue
            }

            if ch == "\\" {
                isEscaping = true
                continue
            }

            if let quote = activeQuote {
                if ch == quote {
                    activeQuote = nil
                } else {
                    current.append(ch)
                }
                continue
            }

            if ch == "'" || ch == "\"" {
                activeQuote = ch
                continue
            }

            if ch.isWhitespace {
                if !current.isEmpty {
                    tokens.append(current)
                    current.removeAll(keepingCapacity: true)
                }
                continue
            }

            current.append(ch)
        }

        if isEscaping {
            current.append("\\")
        }

        if let quote = activeQuote {
            throw CommandLineTokenizerError.unterminatedQuote(quote)
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }
}
