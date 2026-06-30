// JSONFormatter.swift
// Pretty-print and minify operating on the ordered JSONValue model so that
// object key insertion order is always preserved.

import Foundation

public enum IndentStyle {
    case spaces(Int)
    case tab

    var unit: String {
        switch self {
        case .spaces(let n): return String(repeating: " ", count: max(0, n))
        case .tab: return "\t"
        }
    }
}

public enum JSONFormatter {

    // MARK: - Public entry points

    /// Pretty-print a JSON string with the given indent style.
    /// Throws JSONParseError if the input is not valid JSON.
    public static func prettyPrint(_ text: String, indent: IndentStyle = .spaces(2)) throws -> String {
        let value = try JSONParser.parse(text)
        return prettyPrint(value, indent: indent)
    }

    /// Pretty-print a parsed value.
    public static func prettyPrint(_ value: JSONValue, indent: IndentStyle = .spaces(2)) -> String {
        var out = ""
        writePretty(value, indent: indent, level: 0, into: &out)
        return out
    }

    /// Minify a JSON string to a single compact line.
    /// Throws JSONParseError if the input is not valid JSON.
    public static func minify(_ text: String) throws -> String {
        let value = try JSONParser.parse(text)
        return minify(value)
    }

    /// Minify a parsed value.
    public static func minify(_ value: JSONValue) -> String {
        var out = ""
        writeMinified(value, into: &out)
        return out
    }

    // MARK: - Pretty

    private static func writePretty(_ value: JSONValue, indent: IndentStyle, level: Int, into out: inout String) {
        switch value {
        case .object(let pairs):
            if pairs.isEmpty {
                out += "{}"
                return
            }
            out += "{\n"
            let childPad = String(repeating: indent.unit, count: level + 1)
            for (i, pair) in pairs.enumerated() {
                out += childPad
                out += encodeString(pair.0)
                out += ": "
                writePretty(pair.1, indent: indent, level: level + 1, into: &out)
                out += (i == pairs.count - 1) ? "\n" : ",\n"
            }
            out += String(repeating: indent.unit, count: level)
            out += "}"

        case .array(let items):
            if items.isEmpty {
                out += "[]"
                return
            }
            out += "[\n"
            let childPad = String(repeating: indent.unit, count: level + 1)
            for (i, item) in items.enumerated() {
                out += childPad
                writePretty(item, indent: indent, level: level + 1, into: &out)
                out += (i == items.count - 1) ? "\n" : ",\n"
            }
            out += String(repeating: indent.unit, count: level)
            out += "]"

        case .string(let s):
            out += encodeString(s)
        case .number(let n):
            out += n
        case .bool(let b):
            out += b ? "true" : "false"
        case .null:
            out += "null"
        }
    }

    // MARK: - Minify

    private static func writeMinified(_ value: JSONValue, into out: inout String) {
        switch value {
        case .object(let pairs):
            out += "{"
            for (i, pair) in pairs.enumerated() {
                if i > 0 { out += "," }
                out += encodeString(pair.0)
                out += ":"
                writeMinified(pair.1, into: &out)
            }
            out += "}"
        case .array(let items):
            out += "["
            for (i, item) in items.enumerated() {
                if i > 0 { out += "," }
                writeMinified(item, into: &out)
            }
            out += "]"
        case .string(let s):
            out += encodeString(s)
        case .number(let n):
            out += n
        case .bool(let b):
            out += b ? "true" : "false"
        case .null:
            out += "null"
        }
    }

    // MARK: - String encoding

    /// Encodes a Swift string as a JSON string literal (with surrounding quotes),
    /// escaping the characters JSON requires to be escaped.
    static func encodeString(_ s: String) -> String {
        var out = "\""
        for scalar in s.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\t": out += "\\t"
            case "\r": out += "\\r"
            case Unicode.Scalar(0x08): out += "\\b"
            case Unicode.Scalar(0x0C): out += "\\f"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        out += "\""
        return out
    }
}
