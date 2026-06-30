// JSONError.swift
// Parse error carrying 1-based line and column plus a human-readable message.

import Foundation

public struct JSONParseError: Error, Equatable, CustomStringConvertible {
    public let line: Int
    public let column: Int
    public let message: String

    public init(line: Int, column: Int, message: String) {
        self.line = line
        self.column = column
        self.message = message
    }

    public var description: String {
        "line \(line), column \(column): \(message)"
    }
}
