// HighlightedJSONView.swift
// D12: Syntax-highlighted formatted JSON. Builds an AttributedString by walking
// the ORDERED JSONValue model with the same indentation rules as
// JSONFormatter.prettyPrint, emitting a colored run per token type. Colors come
// from JSONSyntaxColors so they adapt to light/dark mode.

import SwiftUI

struct HighlightedJSONView: View {
    let value: JSONValue
    let indent: IndentStyle

    var body: some View {
        ScrollView {
            Text(Self.highlight(value, indent: indent))
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
    }

    // MARK: - AttributedString builder

    /// Render `value` as a colored AttributedString using the same layout as
    /// JSONFormatter.prettyPrint (object key order preserved, identical indent).
    static func highlight(_ value: JSONValue, indent: IndentStyle) -> AttributedString {
        var out = AttributedString()
        write(value, indent: indent, level: 0, into: &out)
        return out
    }

    private static func append(_ text: String, _ color: Color, into out: inout AttributedString) {
        var run = AttributedString(text)
        run.foregroundColor = color
        out.append(run)
    }

    private static func write(_ value: JSONValue, indent: IndentStyle, level: Int, into out: inout AttributedString) {
        switch value {
        case .object(let pairs):
            if pairs.isEmpty {
                append("{}", JSONSyntaxColors.punctuation, into: &out)
                return
            }
            append("{\n", JSONSyntaxColors.punctuation, into: &out)
            let childPad = String(repeating: indent.unit, count: level + 1)
            for (i, pair) in pairs.enumerated() {
                append(childPad, JSONSyntaxColors.punctuation, into: &out)
                append(JSONFormatter.encodeString(pair.0), JSONSyntaxColors.key, into: &out)
                append(": ", JSONSyntaxColors.punctuation, into: &out)
                write(pair.1, indent: indent, level: level + 1, into: &out)
                append(i == pairs.count - 1 ? "\n" : ",\n", JSONSyntaxColors.punctuation, into: &out)
            }
            append(String(repeating: indent.unit, count: level) + "}", JSONSyntaxColors.punctuation, into: &out)

        case .array(let items):
            if items.isEmpty {
                append("[]", JSONSyntaxColors.punctuation, into: &out)
                return
            }
            append("[\n", JSONSyntaxColors.punctuation, into: &out)
            let childPad = String(repeating: indent.unit, count: level + 1)
            for (i, item) in items.enumerated() {
                append(childPad, JSONSyntaxColors.punctuation, into: &out)
                write(item, indent: indent, level: level + 1, into: &out)
                append(i == items.count - 1 ? "\n" : ",\n", JSONSyntaxColors.punctuation, into: &out)
            }
            append(String(repeating: indent.unit, count: level) + "]", JSONSyntaxColors.punctuation, into: &out)

        case .string(let s):
            append(JSONFormatter.encodeString(s), JSONSyntaxColors.string, into: &out)
        case .number(let n):
            append(n, JSONSyntaxColors.number, into: &out)
        case .bool(let b):
            append(b ? "true" : "false", JSONSyntaxColors.bool, into: &out)
        case .null:
            append("null", JSONSyntaxColors.null, into: &out)
        }
    }
}
