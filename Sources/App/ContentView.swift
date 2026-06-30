// ContentView.swift
// Main two-pane editor window: editable input (left) + read-only output (right),
// a toolbar of actions, an indent picker, an inline status line, and the
// extraction path field + Extract button.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            statusBar
            Divider()
            panes
            Divider()
            extractionBar
        }
        .frame(minWidth: 760, minHeight: 480)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button(action: model.beautify) {
                Label("Beautify", systemImage: "wand.and.stars")
            }
            Button(action: model.minify) {
                Label("Minify", systemImage: "arrow.down.right.and.arrow.up.left")
            }
            Button(action: model.validate) {
                Label("Validate", systemImage: "checkmark.seal")
            }
            Button(action: model.clear) {
                Label("Clear", systemImage: "trash")
            }

            Spacer()

            Picker("Indent", selection: $model.indent) {
                ForEach(IndentOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 160)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Status

    @ViewBuilder
    private var statusBar: some View {
        HStack(spacing: 6) {
            switch model.status {
            case .none:
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                Text("Enter JSON, then Beautify / Minify / Validate.")
                    .foregroundColor(.secondary)
            case .valid:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Valid JSON")
                    .foregroundColor(.green)
            case .error(let message):
                Image(systemName: "xmark.octagon.fill")
                    .foregroundColor(.red)
                Text(message)
                    .foregroundColor(.red)
                    .textSelection(.enabled)
            }
            Spacer()
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Editor panes

    private var panes: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 4) {
                Text("Input")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                TextEditor(text: $model.inputText)
                    .font(.system(.body, design: .monospaced))
                    .padding(4)
            }
            .frame(minWidth: 260)
            .background(Color(nsColor: .textBackgroundColor))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Output")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("View", selection: $model.outputMode) {
                        ForEach(OutputMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 140)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                outputContent
            }
            .frame(minWidth: 260)
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }

    // MARK: - Output content (Text / Tree)

    @ViewBuilder
    private var outputContent: some View {
        if model.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ScrollView {
                Text(" ")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
        } else {
            switch model.parsedInput {
            case .success(let value):
                switch model.outputMode {
                case .text:
                    switch model.formatMode {
                    case .beautify:
                        HighlightedJSONView(value: value, indent: model.indent.style)
                    case .minify:
                        ScrollView([.horizontal, .vertical]) {
                            Text(JSONFormatter.minify(value))
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                    }
                case .tree:
                    JSONTreeView(value: value)
                }
            case .failure(let message):
                ScrollView {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.octagon.fill").foregroundColor(.red)
                        Text(message)
                            .foregroundColor(.red)
                            .textSelection(.enabled)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
            }
        }
    }

    // MARK: - Extraction

    private var extractionBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("Path:")
                    .font(.system(size: 12, weight: .medium))
                TextField("$[*].id", text: $model.pathQuery)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit(runExtract)
                Button(action: runExtract) {
                    Label("Extract", systemImage: "arrow.up.forward.app")
                }
                .keyboardShortcut(.return, modifiers: [.command])
            }
            Text("Examples:  $[*].id    .data.items[0]    ['key']    $.users[*].name")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func runExtract() {
        _ = model.extract()
        openWindow(id: "result")
    }
}
