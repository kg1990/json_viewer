// JSONValidator.swift
// Validate a JSON string, returning either .valid or .invalid with the parse
// error (line, column, message).

import Foundation

public enum ValidationResult: Equatable {
    case valid
    case invalid(JSONParseError)
}

public enum JSONValidator {
    /// Validate a JSON document. Never throws.
    public static func validate(_ text: String) -> ValidationResult {
        do {
            _ = try JSONParser.parse(text)
            return .valid
        } catch let e as JSONParseError {
            return .invalid(e)
        } catch {
            return .invalid(JSONParseError(line: 0, column: 0, message: "\(error)"))
        }
    }
}
