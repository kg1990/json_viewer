// ResultView.swift
// Separate window rendering the latest JSONPath extraction result.
// Provides Copy (NSPasteboard) and Download (NSSavePanel) actions.

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ResultView: View {
    @EnvironmentObject private var model: AppModel

    private var payload: ResultPayload? { model.latestResult }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(minWidth: 480, minHeight: 360)
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let payload, payload.isError {
                Image(systemName: "xmark.octagon.fill").foregroundColor(.red)
                Text("Extraction failed")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.red)
            } else {
                Image(systemName: "list.bullet.rectangle").foregroundColor(.accentColor)
                Text("\(payload?.count ?? 0) item(s) extracted")
                    .font(.system(size: 13, weight: .semibold))
            }
            Spacer()
            if let payload, !payload.path.isEmpty {
                Text(payload.path)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var content: some View {
        ScrollView {
            Text(payload?.text ?? "No result yet.")
                .font(.system(.body, design: .monospaced))
                .foregroundColor((payload?.isError ?? false) ? .red : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button(action: copy) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Button(action: download) {
                Label("Download", systemImage: "square.and.arrow.down")
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func copy() {
        guard let text = payload?.text else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func download() {
        guard let text = payload?.text else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json, .plainText]
        panel.nameFieldStringValue = "extraction.json"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
