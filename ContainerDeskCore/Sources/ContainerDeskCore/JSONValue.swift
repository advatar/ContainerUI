import Foundation

/// A small JSON value type for decoding unknown JSON structures without relying on fragile schemas.
public enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        if let b = try? container.decode(Bool.self) {
            self = .bool(b)
            return
        }

        if let n = try? container.decode(Double.self) {
            self = .number(n)
            return
        }

        if let s = try? container.decode(String.self) {
            self = .string(s)
            return
        }

        if let a = try? container.decode([JSONValue].self) {
            self = .array(a)
            return
        }

        if let o = try? container.decode([String: JSONValue].self) {
            self = .object(o)
            return
        }

        throw DecodingError.typeMismatch(
            JSONValue.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value")
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s):
            try container.encode(s)
        case .number(let n):
            try container.encode(n)
        case .bool(let b):
            try container.encode(b)
        case .object(let o):
            try container.encode(o)
        case .array(let a):
            try container.encode(a)
        case .null:
            try container.encodeNil()
        }
    }

    public var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .number(let n):
            // Preserve integers cleanly if possible
            if n.rounded(.towardZero) == n { return String(Int64(n)) }
            return String(n)
        case .bool(let b): return b ? "true" : "false"
        case .null: return nil
        case .object, .array: return nil
        }
    }

    public var boolValue: Bool? {
        switch self {
        case .bool(let b): return b
        case .string(let s):
            switch s.lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        case .number(let n): return n != 0
        default: return nil
        }
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }
}

public extension Dictionary where Key == String, Value == JSONValue {
    /// Returns the first matching value for a list of candidate keys, case-insensitively.
    func firstValue(forKeys keys: [String]) -> JSONValue? {
        if keys.isEmpty { return nil }
        let lowerToActual: [String: String] = Swift.Dictionary<String, String>(
            uniqueKeysWithValues: self.keys.map { ($0.lowercased(), $0) }
        )
        for key in keys {
            if let actual = lowerToActual[key.lowercased()], let v = self[actual] {
                return v
            }
        }
        return nil
    }

    func firstString(forKeys keys: [String]) -> String? {
        firstValue(forKeys: keys)?.stringValue
    }

    func firstBool(forKeys keys: [String]) -> Bool? {
        firstValue(forKeys: keys)?.boolValue
    }
}
