// AppModel.swift
// Shared observable state for the JSON Viewer GUI.

import SwiftUI
import Foundation

/// Indent options surfaced in the toolbar picker.
enum IndentOption: String, CaseIterable, Identifiable {
    case twoSpaces = "2 Spaces"
    case fourSpaces = "4 Spaces"
    case tab = "Tab"

    var id: String { rawValue }

    var style: IndentStyle {
        switch self {
        case .twoSpaces: return .spaces(2)
        case .fourSpaces: return .spaces(4)
        case .tab: return .tab
        }
    }
}

/// Inline validation / operation status shown under the toolbar.
enum StatusMessage: Equatable {
    case none
    case valid
    case error(String)
}

/// Output pane rendering mode surfaced by the segmented picker (D14).
enum OutputMode: String, CaseIterable, Identifiable {
    case text = "Text"
    case tree = "Tree"

    var id: String { rawValue }
}

/// How the Text output pane formats valid JSON: multi-line pretty vs. compact.
enum FormatMode {
    case beautify
    case minify
}

/// Result of safely parsing the current input for the Text/Tree views.
enum ParsedInput {
    case success(JSONValue)
    case failure(String)
}

/// One extraction result rendered in a separate result window.
struct ResultPayload: Identifiable, Equatable {
    let id = UUID()
    let path: String
    let text: String
    let count: Int
    let isError: Bool
}

/// App-wide observable model. Holds the editor text, indent choice, status,
/// and the latest extraction payload consumed by the result window.
final class AppModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var pathQuery: String = ""
    @Published var indent: IndentOption = .twoSpaces
    @Published var status: StatusMessage = .none

    /// Output pane mode (Text highlighting vs. collapsible tree).
    @Published var outputMode: OutputMode = .text

    /// How the Text output pane formats valid JSON. Toggled by beautify()/minify().
    @Published var formatMode: FormatMode = .beautify

    /// The current input parsed into the ordered model, or the parse error.
    /// Used by the Text/Tree views; never throws so the UI cannot crash.
    var parsedInput: ParsedInput {
        do {
            return .success(try JSONParser.parse(inputText))
        } catch let e as JSONParseError {
            return .failure(e.description)
        } catch {
            return .failure("\(error)")
        }
    }

    /// Latest extraction payload. The result window renders this.
    @Published var latestResult: ResultPayload?

    // MARK: - Toolbar actions

    func beautify() {
        formatMode = .beautify
        do {
            _ = try JSONFormatter.prettyPrint(inputText, indent: indent.style)
            status = .valid
        } catch let e as JSONParseError {
            status = .error(e.description)
        } catch {
            status = .error("\(error)")
        }
    }

    func minify() {
        formatMode = .minify
        do {
            _ = try JSONFormatter.minify(inputText)
            status = .valid
        } catch let e as JSONParseError {
            status = .error(e.description)
        } catch {
            status = .error("\(error)")
        }
    }

    func validate() {
        switch JSONValidator.validate(inputText) {
        case .valid:
            status = .valid
        case .invalid(let e):
            status = .error(e.description)
        }
    }

    func clear() {
        inputText = ""
        status = .none
    }

    /// Run the path query against the current input and produce a ResultPayload.
    /// Never throws to the caller; errors are captured into the payload.
    func extract() -> ResultPayload {
        let path = pathQuery
        do {
            let results = try JSONPath.extract(path, from: inputText)
            let text = JSONFormatter.prettyPrint(.array(results), indent: indent.style)
            let payload = ResultPayload(path: path, text: text, count: results.count, isError: false)
            latestResult = payload
            return payload
        } catch let e as JSONPathError {
            let payload = ResultPayload(path: path, text: "Path error: \(e.message)", count: 0, isError: true)
            latestResult = payload
            return payload
        } catch let e as JSONParseError {
            let payload = ResultPayload(path: path, text: "Parse error: \(e.description)", count: 0, isError: true)
            latestResult = payload
            return payload
        } catch {
            let payload = ResultPayload(path: path, text: "Error: \(error)", count: 0, isError: true)
            latestResult = payload
            return payload
        }
    }
}
