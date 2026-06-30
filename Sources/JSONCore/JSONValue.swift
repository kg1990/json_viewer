// JSONValue.swift
// Ordered JSON model. Object key insertion order is preserved by using an
// array of (key, value) pairs rather than a Dictionary.
//
// Numbers are stored as their original literal string so they round-trip
// exactly (e.g. `1` stays `1`, `1.0` stays `1.0`, `1e10` stays `1e10`).

import Foundation

public indirect enum JSONValue: Equatable {
    case object([(String, JSONValue)])
    case array([JSONValue])
    case string(String)
    /// Stores the raw numeric literal exactly as it appeared in the source.
    case number(String)
    case bool(Bool)
    case null

    public static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
        switch (lhs, rhs) {
        case let (.object(a), .object(b)):
            guard a.count == b.count else { return false }
            for (x, y) in zip(a, b) {
                if x.0 != y.0 || x.1 != y.1 { return false }
            }
            return true
        case let (.array(a), .array(b)):
            return a == b
        case let (.string(a), .string(b)):
            return a == b
        case let (.number(a), .number(b)):
            return a == b
        case let (.bool(a), .bool(b)):
            return a == b
        case (.null, .null):
            return true
        default:
            return false
        }
    }
}
