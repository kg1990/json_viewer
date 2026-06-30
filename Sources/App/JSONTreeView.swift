// JSONTreeView.swift
// D13: Collapsible tree over the ordered JSONValue model. Objects and arrays are
// expandable via DisclosureGroup; scalars render inline with the D12 color
// scheme. The top level is expanded by default, deeper nodes start collapsed.

import SwiftUI

struct JSONTreeView: View {
    let value: JSONValue

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 2) {
                JSONTreeNode(label: nil, isIndex: false, value: value, startExpanded: true)
            }
            .font(.system(.body, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        }
    }
}

/// A single node. `label` is the object key or array index for this node (nil
/// for the root). `isIndex` tells whether the label is an array index so it can
/// be styled and bracketed distinctly from an object key.
private struct JSONTreeNode: View {
    let label: String?
    let isIndex: Bool
    let value: JSONValue
    let startExpanded: Bool

    @State private var isExpanded: Bool

    init(label: String?, isIndex: Bool, value: JSONValue, startExpanded: Bool) {
        self.label = label
        self.isIndex = isIndex
        self.value = value
        self.startExpanded = startExpanded
        _isExpanded = State(initialValue: startExpanded)
    }

    var body: some View {
        switch value {
        case .object(let pairs):
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                        JSONTreeNode(label: pair.0, isIndex: false, value: pair.1, startExpanded: false)
                    }
                }
                .padding(.leading, 14)
            } label: {
                disclosureLabel(badge: "{\(pairs.count)}")
            }
        case .array(let items):
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        JSONTreeNode(label: "\(index)", isIndex: true, value: item, startExpanded: false)
                    }
                }
                .padding(.leading, 14)
            } label: {
                disclosureLabel(badge: "[\(items.count)]")
            }
        default:
            scalarRow
        }
    }

    // MARK: - Expandable container label (object / array)

    private func disclosureLabel(badge: String) -> some View {
        HStack(spacing: 4) {
            labelText
            Text(badge)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Scalar leaf row

    private var scalarRow: some View {
        HStack(spacing: 4) {
            if label != nil {
                labelText
                Text(":")
                    .foregroundColor(.secondary)
            }
            scalarValueText
        }
    }

    @ViewBuilder
    private var labelText: some View {
        if let label {
            Text(isIndex ? "[\(label)]" : "\"\(label)\"")
                .foregroundColor(isIndex ? JSONSyntaxColors.number : JSONSyntaxColors.key)
        }
    }

    @ViewBuilder
    private var scalarValueText: some View {
        switch value {
        case .string(let s):
            Text(JSONFormatter.encodeString(s))
                .foregroundColor(JSONSyntaxColors.string)
                .textSelection(.enabled)
        case .number(let n):
            Text(n)
                .foregroundColor(JSONSyntaxColors.number)
                .textSelection(.enabled)
        case .bool(let b):
            Text(b ? "true" : "false")
                .foregroundColor(JSONSyntaxColors.bool)
        case .null:
            Text("null")
                .foregroundColor(JSONSyntaxColors.null)
        case .object, .array:
            EmptyView() // handled by container
        }
    }
}
