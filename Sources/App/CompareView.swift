// CompareView.swift
// D4: JSON Compare window. Two side-by-side editors (A original / B compare),
// a summary bar, and a recursive tree diff rendered from the JSONDiff engine.
// All diffing is guarded by do/catch so invalid input shows a red error rather
// than crashing.

import SwiftUI
import AppKit

struct CompareView: View {
    @EnvironmentObject private var model: AppModel

    /// Result of comparing the two inputs: either a diff root or an error/hint.
    private enum CompareState {
        case empty
        case error(String)
        case diff(DiffNode)
    }

    /// Recompute the diff each render. Inputs are small, so this is cheap and
    /// keeps the tree in sync with compareA/compareB automatically.
    private var state: CompareState {
        let aTrim = model.compareA.trimmingCharacters(in: .whitespacesAndNewlines)
        let bTrim = model.compareB.trimmingCharacters(in: .whitespacesAndNewlines)
        if aTrim.isEmpty || bTrim.isEmpty {
            return .empty
        }
        do {
            return .diff(try JSONDiff.compare(model.compareA, model.compareB))
        } catch let e as JSONParseError {
            return .error("Invalid JSON in A or B: \(e.description)")
        } catch {
            return .error("Invalid JSON in A or B: \(error)")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            editors
            Divider()
            summaryBar
            Divider()
            diffArea
        }
        .frame(minWidth: 720, minHeight: 480)
    }

    // MARK: - Editors

    private var editors: some View {
        HSplitView {
            editor(title: "A (original)", text: $model.compareA)
                .background(Color(nsColor: .textBackgroundColor))
            editor(title: "B (compare)", text: $model.compareB)
                .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(minHeight: 160)
    }

    private func editor(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.top, 8)
            TextEditor(text: text)
                .font(.system(.body, design: .monospaced))
                .padding(4)
        }
        .frame(minWidth: 260)
    }

    // MARK: - Summary

    @ViewBuilder
    private var summaryBar: some View {
        HStack(spacing: 6) {
            switch state {
            case .diff(let root):
                let s = JSONDiff.summarize(root)
                Image(systemName: "rectangle.split.2x1")
                    .foregroundColor(.secondary)
                Text("\(s.added) added")
                    .foregroundColor(DiffColors.added)
                Text("·").foregroundColor(.secondary)
                Text("\(s.removed) removed")
                    .foregroundColor(DiffColors.removed)
                Text("·").foregroundColor(.secondary)
                Text("\(s.changed) changed")
                    .foregroundColor(DiffColors.changed)
            case .error:
                Image(systemName: "xmark.octagon.fill").foregroundColor(.red)
                Text("Diff unavailable").foregroundColor(.red)
            case .empty:
                Image(systemName: "info.circle").foregroundColor(.secondary)
                Text("Enter JSON in both A and B to compare.")
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Diff area

    @ViewBuilder
    private var diffArea: some View {
        switch state {
        case .empty:
            ScrollView {
                Text("No comparison yet.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(Color(nsColor: .controlBackgroundColor))
        case .error(let message):
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
            .background(Color(nsColor: .controlBackgroundColor))
        case .diff(let root):
            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 2) {
                    DiffNodeView(node: root, startExpanded: true)
                }
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }
}

// MARK: - Status -> color mapping

private enum DiffColors {
    static let added = Color(nsColor: .systemGreen)
    static let removed = Color(nsColor: .systemRed)
    static let changed = Color(nsColor: .systemOrange)
    static let unchanged = Color.secondary

    static func color(for status: DiffStatus) -> Color {
        switch status {
        case .added: return added
        case .removed: return removed
        case .changed: return changed
        case .unchanged: return unchanged
        }
    }
}

// MARK: - Recursive diff node row

/// One node of the diff tree. Containers (object/array with children) render as
/// a DisclosureGroup; leaves render a single colored row. Mirrors JSONTreeView.
private struct DiffNodeView: View {
    let node: DiffNode
    let startExpanded: Bool

    @State private var isExpanded: Bool

    init(node: DiffNode, startExpanded: Bool) {
        self.node = node
        self.startExpanded = startExpanded
        _isExpanded = State(initialValue: startExpanded)
    }

    private var isContainer: Bool {
        (node.kind == .object || node.kind == .array) && !node.children.isEmpty
    }

    var body: some View {
        if isContainer {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
                        DiffNodeView(node: child, startExpanded: false)
                    }
                }
                .padding(.leading, 14)
            } label: {
                containerLabel
            }
        } else {
            leafRow
        }
    }

    private var badge: String {
        switch node.kind {
        case .object: return "{\(node.children.count)}"
        case .array: return "[\(node.children.count)]"
        case .leaf: return ""
        }
    }

    private var containerLabel: some View {
        HStack(spacing: 4) {
            Text(node.label)
                .foregroundColor(DiffColors.color(for: node.status))
            Text(badge)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var leafRow: some View {
        HStack(spacing: 4) {
            Text(node.label)
                .foregroundColor(DiffColors.color(for: node.status))
            Text(":")
                .foregroundColor(.secondary)
            valueText
        }
    }

    @ViewBuilder
    private var valueText: some View {
        let color = DiffColors.color(for: node.status)
        switch node.status {
        case .changed:
            HStack(spacing: 4) {
                Text(render(node.oldValue)).foregroundColor(DiffColors.removed)
                Text("→").foregroundColor(.secondary)
                Text(render(node.newValue)).foregroundColor(DiffColors.added)
            }
            .textSelection(.enabled)
        case .added:
            Text(render(node.newValue)).foregroundColor(color).textSelection(.enabled)
        case .removed:
            Text(render(node.oldValue)).foregroundColor(color).textSelection(.enabled)
        case .unchanged:
            Text(render(node.newValue ?? node.oldValue))
                .foregroundColor(color).textSelection(.enabled)
        }
    }

    /// Compact display of a scalar/container value for a diff row.
    private func render(_ value: JSONValue?) -> String {
        guard let value else { return "—" }
        switch value {
        case .string(let s): return JSONFormatter.encodeString(s)
        case .number(let n): return n
        case .bool(let b): return b ? "true" : "false"
        case .null: return "null"
        case .object, .array: return JSONFormatter.minify(value)
        }
    }
}
