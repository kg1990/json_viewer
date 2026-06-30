// JSONPath.swift
// A JSONPath SUBSET extraction engine over the ordered JSONValue model.
//
// Supported syntax:
//   - optional leading `$`
//   - `.key`                  (object member access)
//   - `['key']`               (object member access, quoted)
//   - `[<integer>]`           (array index access)
//   - `[*]`                   (wildcard over array elements)
//   chained arbitrarily.
//
// Semantics:
//   - Missing keys / out-of-range indices / type mismatches on an element are
//     skipped (the element is dropped from the working set), never crash.
//   - Matched values are returned as an ordered array, preserving document
//     order at each wildcard expansion.

import Foundation

/// A single step in a parsed JSONPath.
enum PathComponent: Equatable {
    case key(String)
    case index(Int)
    case wildcard
}

public struct JSONPathError: Error, Equatable, CustomStringConvertible {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var description: String { message }
}

public enum JSONPath {

    /// Extract all values matching `path` from `text`.
    /// Throws JSONParseError if `text` is invalid JSON, or JSONPathError if the
    /// path syntax is invalid. Returns an ordered array (possibly empty).
    public static func extract(_ path: String, from text: String) throws -> [JSONValue] {
        let root = try JSONParser.parse(text)
        return try extract(path, from: root)
    }

    /// Extract all values matching `path` from a parsed value.
    public static func extract(_ path: String, from root: JSONValue) throws -> [JSONValue] {
        let components = try parse(path)
        var current: [JSONValue] = [root]
        for component in components {
            var next: [JSONValue] = []
            for value in current {
                apply(component, to: value, into: &next)
            }
            current = next
        }
        return current
    }

    // MARK: - Apply one component (skip on mismatch)

    private static func apply(_ component: PathComponent, to value: JSONValue, into out: inout [JSONValue]) {
        switch component {
        case .key(let k):
            if case .object(let pairs) = value {
                // First matching key (objects normally have unique keys).
                if let match = pairs.first(where: { $0.0 == k }) {
                    out.append(match.1)
                }
            }
            // Non-object or missing key -> skipped.
        case .index(let i):
            if case .array(let items) = value {
                let actual = i >= 0 ? i : items.count + i
                if actual >= 0 && actual < items.count {
                    out.append(items[actual])
                }
            }
            // Non-array or out of range -> skipped.
        case .wildcard:
            if case .array(let items) = value {
                out.append(contentsOf: items)
            }
            // Non-array -> skipped.
        }
    }

    // MARK: - Path parsing

    static func parse(_ path: String) throws -> [PathComponent] {
        let chars = Array(path)
        var i = 0
        var components: [PathComponent] = []

        // Optional leading '$'.
        if i < chars.count && chars[i] == "$" {
            i += 1
        }

        while i < chars.count {
            let c = chars[i]
            if c == "." {
                i += 1
                // Allow `..`? Not supported; require a key name to follow.
                let start = i
                while i < chars.count && chars[i] != "." && chars[i] != "[" {
                    i += 1
                }
                let name = String(chars[start..<i])
                if name.isEmpty {
                    throw JSONPathError("expected key name after '.' in path")
                }
                components.append(.key(name))
            } else if c == "[" {
                i += 1
                guard i < chars.count else {
                    throw JSONPathError("unterminated '[' in path")
                }
                if chars[i] == "*" {
                    i += 1
                    guard i < chars.count && chars[i] == "]" else {
                        throw JSONPathError("expected ']' after '[*' in path")
                    }
                    i += 1
                    components.append(.wildcard)
                } else if chars[i] == "'" || chars[i] == "\"" {
                    let quote = chars[i]
                    i += 1
                    let start = i
                    while i < chars.count && chars[i] != quote {
                        i += 1
                    }
                    guard i < chars.count else {
                        throw JSONPathError("unterminated quoted key in path")
                    }
                    let name = String(chars[start..<i])
                    i += 1 // closing quote
                    guard i < chars.count && chars[i] == "]" else {
                        throw JSONPathError("expected ']' after quoted key in path")
                    }
                    i += 1
                    components.append(.key(name))
                } else {
                    // Integer index (possibly negative).
                    let start = i
                    if chars[i] == "-" { i += 1 }
                    while i < chars.count && chars[i].isNumber {
                        i += 1
                    }
                    let numStr = String(chars[start..<i])
                    guard let idx = Int(numStr) else {
                        throw JSONPathError("invalid array index '\(numStr)' in path")
                    }
                    guard i < chars.count && chars[i] == "]" else {
                        throw JSONPathError("expected ']' after index in path")
                    }
                    i += 1
                    components.append(.index(idx))
                }
            } else {
                // Leading bare key (no '$' and no leading '.'), e.g. `data.items`.
                if components.isEmpty {
                    let start = i
                    while i < chars.count && chars[i] != "." && chars[i] != "[" {
                        i += 1
                    }
                    let name = String(chars[start..<i])
                    if name.isEmpty {
                        throw JSONPathError("unexpected character in path")
                    }
                    components.append(.key(name))
                } else {
                    throw JSONPathError("unexpected character '\(c)' in path")
                }
            }
        }
        return components
    }
}
