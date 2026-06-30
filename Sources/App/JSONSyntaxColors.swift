// JSONSyntaxColors.swift
// Shared adaptive color scheme for JSON token types, used by both the
// highlighted text view (D12) and the tree view (D13). System colors are used
// so the palette stays legible in both light and dark appearances.

import SwiftUI
import AppKit

enum JSONSyntaxColors {
    /// Object keys.
    static let key = Color(nsColor: .systemTeal)
    /// String values.
    static let string = Color(nsColor: .systemRed)
    /// Numeric literals.
    static let number = Color(nsColor: .systemBlue)
    /// Booleans.
    static let bool = Color(nsColor: .systemPurple)
    /// null.
    static let null = Color(nsColor: .systemGray)
    /// Structural punctuation ({}, [], commas, colons).
    static let punctuation = Color.primary
}
