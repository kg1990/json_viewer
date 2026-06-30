// JSONParser.swift
// A small hand-written recursive-descent JSON parser producing an ordered
// model (JSONValue). Tracks line/column for precise error reporting.
//
// Handles: nested structures, escaped strings (\" \\ \/ \n \t \r \b \f \uXXXX
// including surrogate pairs), negative/exponent numbers, true/false/null,
// empty object/array, unicode. Numbers are kept as raw literal strings.

import Foundation

public struct JSONParser {

    private let scalars: [Unicode.Scalar]
    private var index: Int = 0
    // 1-based position of `index`.
    private var line: Int = 1
    private var column: Int = 1

    public init(_ text: String) {
        self.scalars = Array(text.unicodeScalars)
    }

    /// Parse a complete JSON document. Throws JSONParseError on failure.
    public static func parse(_ text: String) throws -> JSONValue {
        var parser = JSONParser(text)
        return try parser.parseDocument()
    }

    // MARK: - Cursor helpers

    private var isAtEnd: Bool { index >= scalars.count }

    private func peek() -> Unicode.Scalar? {
        isAtEnd ? nil : scalars[index]
    }

    private mutating func advance() -> Unicode.Scalar {
        let s = scalars[index]
        index += 1
        if s == "\n" {
            line += 1
            column = 1
        } else {
            column += 1
        }
        return s
    }

    private func error(_ message: String) -> JSONParseError {
        JSONParseError(line: line, column: column, message: message)
    }

    // MARK: - Document

    private mutating func parseDocument() throws -> JSONValue {
        skipWhitespace()
        if isAtEnd {
            throw error("unexpected end of input; expected a JSON value")
        }
        let value = try parseValue()
        skipWhitespace()
        if !isAtEnd {
            throw error("unexpected trailing characters after JSON value")
        }
        return value
    }

    private mutating func skipWhitespace() {
        while let c = peek(), c == " " || c == "\t" || c == "\n" || c == "\r" {
            _ = advance()
        }
    }

    // MARK: - Value dispatch

    private mutating func parseValue() throws -> JSONValue {
        skipWhitespace()
        guard let c = peek() else {
            throw error("unexpected end of input; expected a JSON value")
        }
        switch c {
        case "{": return try parseObject()
        case "[": return try parseArray()
        case "\"": return .string(try parseString())
        case "t", "f": return try parseBool()
        case "n": return try parseNull()
        case "-", "0"..."9": return try parseNumber()
        default:
            throw error("unexpected character '\(c)'; expected a JSON value")
        }
    }

    // MARK: - Object

    private mutating func parseObject() throws -> JSONValue {
        _ = advance() // consume '{'
        var pairs: [(String, JSONValue)] = []
        skipWhitespace()
        if peek() == "}" {
            _ = advance()
            return .object(pairs)
        }
        while true {
            skipWhitespace()
            guard peek() == "\"" else {
                if isAtEnd {
                    throw error("unexpected end of input; expected object key string")
                }
                throw error("expected object key string (keys must be quoted)")
            }
            let key = try parseString()
            skipWhitespace()
            guard peek() == ":" else {
                if isAtEnd {
                    throw error("unexpected end of input; expected ':' after object key")
                }
                throw error("expected ':' after object key")
            }
            _ = advance() // consume ':'
            let value = try parseValue()
            pairs.append((key, value))
            skipWhitespace()
            guard let c = peek() else {
                throw error("unexpected end of input; expected ',' or '}'")
            }
            if c == "," {
                _ = advance()
                skipWhitespace()
                // Reject trailing comma before '}'.
                if peek() == "}" {
                    throw error("trailing comma is not allowed in object")
                }
                continue
            } else if c == "}" {
                _ = advance()
                return .object(pairs)
            } else {
                throw error("expected ',' or '}' in object but found '\(c)'")
            }
        }
    }

    // MARK: - Array

    private mutating func parseArray() throws -> JSONValue {
        _ = advance() // consume '['
        var items: [JSONValue] = []
        skipWhitespace()
        if peek() == "]" {
            _ = advance()
            return .array(items)
        }
        while true {
            let value = try parseValue()
            items.append(value)
            skipWhitespace()
            guard let c = peek() else {
                throw error("unexpected end of input; expected ',' or ']'")
            }
            if c == "," {
                _ = advance()
                skipWhitespace()
                // Reject trailing comma before ']'.
                if peek() == "]" {
                    throw error("trailing comma is not allowed in array")
                }
                continue
            } else if c == "]" {
                _ = advance()
                return .array(items)
            } else {
                throw error("expected ',' or ']' in array but found '\(c)'")
            }
        }
    }

    // MARK: - String

    private mutating func parseString() throws -> String {
        _ = advance() // consume opening '"'
        var result = String.UnicodeScalarView()
        while true {
            guard let c = peek() else {
                throw error("unterminated string literal")
            }
            if c == "\"" {
                _ = advance()
                return String(result)
            } else if c == "\\" {
                _ = advance()
                try parseEscape(into: &result)
            } else if c.value < 0x20 {
                throw error("control character must be escaped in string")
            } else {
                _ = advance()
                result.append(c)
            }
        }
    }

    private mutating func parseEscape(into result: inout String.UnicodeScalarView) throws {
        guard let e = peek() else {
            throw error("unterminated escape sequence")
        }
        switch e {
        case "\"": _ = advance(); result.append("\"")
        case "\\": _ = advance(); result.append("\\")
        case "/":  _ = advance(); result.append("/")
        case "n":  _ = advance(); result.append("\n")
        case "t":  _ = advance(); result.append("\t")
        case "r":  _ = advance(); result.append("\r")
        case "b":  _ = advance(); result.append(Unicode.Scalar(0x08)!)
        case "f":  _ = advance(); result.append(Unicode.Scalar(0x0C)!)
        case "u":
            _ = advance()
            let scalar = try parseUnicodeEscape()
            result.append(scalar)
        default:
            throw error("invalid escape sequence '\\\(e)'")
        }
    }

    /// Parses the four hex digits after `\u`, handling UTF-16 surrogate pairs.
    private mutating func parseUnicodeEscape() throws -> Unicode.Scalar {
        let first = try parseHex4()
        // High surrogate -> expect a following \uXXXX low surrogate.
        if first >= 0xD800 && first <= 0xDBFF {
            guard peek() == "\\" else {
                throw error("expected low surrogate after high surrogate")
            }
            _ = advance()
            guard peek() == "u" else {
                throw error("expected \\u low surrogate after high surrogate")
            }
            _ = advance()
            let second = try parseHex4()
            guard second >= 0xDC00 && second <= 0xDFFF else {
                throw error("invalid low surrogate in \\u escape")
            }
            let combined = 0x10000
                + ((first - 0xD800) << 10)
                + (second - 0xDC00)
            guard let scalar = Unicode.Scalar(combined) else {
                throw error("invalid unicode scalar from surrogate pair")
            }
            return scalar
        }
        // Lone low surrogate is invalid.
        if first >= 0xDC00 && first <= 0xDFFF {
            throw error("unexpected low surrogate in \\u escape")
        }
        guard let scalar = Unicode.Scalar(first) else {
            throw error("invalid \\u escape value")
        }
        return scalar
    }

    private mutating func parseHex4() throws -> Int {
        var value = 0
        for _ in 0..<4 {
            guard let c = peek() else {
                throw error("unterminated \\u escape; expected 4 hex digits")
            }
            guard let digit = hexDigit(c) else {
                throw error("invalid hex digit '\(c)' in \\u escape")
            }
            value = value * 16 + digit
            _ = advance()
        }
        return value
    }

    private func hexDigit(_ c: Unicode.Scalar) -> Int? {
        switch c {
        case "0"..."9": return Int(c.value - 0x30)
        case "a"..."f": return Int(c.value - 0x61 + 10)
        case "A"..."F": return Int(c.value - 0x41 + 10)
        default: return nil
        }
    }

    // MARK: - Number

    private mutating func parseNumber() throws -> JSONValue {
        var literal = String.UnicodeScalarView()

        // Optional minus.
        if peek() == "-" {
            literal.append(advance())
        }

        // Integer part.
        guard let firstDigit = peek(), isDigit(firstDigit) else {
            throw error("invalid number; expected digit")
        }
        if firstDigit == "0" {
            literal.append(advance())
            // No leading zeros allowed (e.g. `01`).
            if let c = peek(), isDigit(c) {
                throw error("invalid number; leading zeros are not allowed")
            }
        } else {
            while let c = peek(), isDigit(c) {
                literal.append(advance())
            }
        }

        // Fractional part.
        if peek() == "." {
            literal.append(advance())
            guard let c = peek(), isDigit(c) else {
                throw error("invalid number; expected digit after decimal point")
            }
            while let c = peek(), isDigit(c) {
                literal.append(advance())
            }
        }

        // Exponent part.
        if let c = peek(), c == "e" || c == "E" {
            literal.append(advance())
            if let sign = peek(), sign == "+" || sign == "-" {
                literal.append(advance())
            }
            guard let d = peek(), isDigit(d) else {
                throw error("invalid number; expected digit in exponent")
            }
            while let d = peek(), isDigit(d) {
                literal.append(advance())
            }
        }

        return .number(String(literal))
    }

    private func isDigit(_ c: Unicode.Scalar) -> Bool {
        c >= "0" && c <= "9"
    }

    // MARK: - Literals

    private mutating func parseBool() throws -> JSONValue {
        if matchKeyword("true") { return .bool(true) }
        if matchKeyword("false") { return .bool(false) }
        throw error("invalid literal; expected 'true' or 'false'")
    }

    private mutating func parseNull() throws -> JSONValue {
        if matchKeyword("null") { return .null }
        throw error("invalid literal; expected 'null'")
    }

    private mutating func matchKeyword(_ keyword: String) -> Bool {
        let kw = Array(keyword.unicodeScalars)
        guard index + kw.count <= scalars.count else { return false }
        for (i, ch) in kw.enumerated() where scalars[index + i] != ch {
            return false
        }
        for _ in kw { _ = advance() }
        return true
    }
}
