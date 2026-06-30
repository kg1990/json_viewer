// JSONDiff.swift
// Pure-logic structural diff between two JSONValue trees.
//
// Semantics:
// - Objects: matched by key, order-insensitive. A-only keys -> removed,
//   B-only keys -> added, shared keys -> recurse. Child ordering is A's keys
//   in A's order followed by B-only keys in B's order.
// - Arrays: matched by index. Shared indices recurse; A-only indices removed;
//   B-only indices added.
// - Scalars: string/bool/null by direct equality. Numbers by numeric value
//   when both literals parse to Double, else raw-literal string equality.
// - Type mismatch: status=changed, no recursion, kind=leaf.
// - Containers of the same type: changed iff any descendant differs.

import Foundation

public enum DiffStatus: String {
    case unchanged, added, removed, changed
}

public struct DiffNode {
    public enum Kind { case object, array, leaf }
    public let label: String          // root = "$"; object child = key name; array child = "[i]"
    public let status: DiffStatus
    public let kind: Kind
    public let oldValue: JSONValue?
    public let newValue: JSONValue?
    public let children: [DiffNode]
    public init(label: String, status: DiffStatus, kind: Kind,
                oldValue: JSONValue?, newValue: JSONValue?, children: [DiffNode]) {
        self.label = label
        self.status = status
        self.kind = kind
        self.oldValue = oldValue
        self.newValue = newValue
        self.children = children
    }
}

public struct DiffSummary: Equatable {
    public let added: Int
    public let removed: Int
    public let changed: Int
    public init(added: Int, removed: Int, changed: Int) {
        self.added = added
        self.removed = removed
        self.changed = changed
    }
}

public enum JSONDiff {

    public static func compare(_ a: JSONValue, _ b: JSONValue) -> DiffNode {
        return diff(label: "$", a: a, b: b)
    }

    public static func compare(_ aText: String, _ bText: String) throws -> DiffNode {
        let a = try JSONParser.parse(aText)
        let b = try JSONParser.parse(bText)
        return compare(a, b)
    }

    public static func summarize(_ root: DiffNode) -> DiffSummary {
        var added = 0, removed = 0, changed = 0
        count(root, &added, &removed, &changed)
        return DiffSummary(added: added, removed: removed, changed: changed)
    }

    // MARK: - Summary counting

    private static func count(_ node: DiffNode, _ added: inout Int,
                              _ removed: inout Int, _ changed: inout Int) {
        switch node.status {
        case .added:
            // Whole added subtree counts as one; do not descend.
            added += 1
            return
        case .removed:
            removed += 1
            return
        case .changed:
            // A "changed" leaf/type-change is a terminal diff and counts.
            // A "changed" container is not itself counted; its differing
            // descendants are counted by recursion below.
            if node.kind == .leaf {
                changed += 1
                return
            }
        case .unchanged:
            break
        }
        for child in node.children {
            count(child, &added, &removed, &changed)
        }
    }

    // MARK: - Diff core

    private static func kind(of value: JSONValue) -> DiffNode.Kind {
        switch value {
        case .object: return .object
        case .array: return .array
        default: return .leaf
        }
    }

    private static func diff(label: String, a: JSONValue, b: JSONValue) -> DiffNode {
        switch (a, b) {
        case let (.object(pa), .object(pb)):
            return diffObject(label: label, a: pa, b: pb, aVal: a, bVal: b)
        case let (.array(ea), .array(eb)):
            return diffArray(label: label, a: ea, b: eb, aVal: a, bVal: b)
        case (.object, _), (_, .object), (.array, _), (_, .array):
            // Type mismatch involving a container (object<->array, container<->scalar).
            return DiffNode(label: label, status: .changed, kind: .leaf,
                            oldValue: a, newValue: b, children: [])
        default:
            // Both scalars.
            if scalarsEqual(a, b) {
                return DiffNode(label: label, status: .unchanged, kind: .leaf,
                                oldValue: a, newValue: b, children: [])
            } else {
                return DiffNode(label: label, status: .changed, kind: .leaf,
                                oldValue: a, newValue: b, children: [])
            }
        }
    }

    private static func diffObject(label: String,
                                   a: [(String, JSONValue)],
                                   b: [(String, JSONValue)],
                                   aVal: JSONValue, bVal: JSONValue) -> DiffNode {
        // Build lookup for B's values by key (last wins on duplicate keys).
        var bByKey: [String: JSONValue] = [:]
        for (k, v) in b { bByKey[k] = v }
        var aKeys = Set<String>()
        for (k, _) in a { aKeys.insert(k) }

        var children: [DiffNode] = []

        // A's keys in A's order.
        for (k, av) in a {
            if let bv = bByKey[k] {
                children.append(diff(label: k, a: av, b: bv))
            } else {
                children.append(DiffNode(label: k, status: .removed, kind: kind(of: av),
                                         oldValue: av, newValue: nil, children: []))
            }
        }
        // B-only keys in B's order.
        for (k, bv) in b where !aKeys.contains(k) {
            children.append(DiffNode(label: k, status: .added, kind: kind(of: bv),
                                     oldValue: nil, newValue: bv, children: []))
        }

        let differs = children.contains { $0.status != .unchanged }
        return DiffNode(label: label, status: differs ? .changed : .unchanged,
                        kind: .object, oldValue: aVal, newValue: bVal, children: children)
    }

    private static func diffArray(label: String,
                                  a: [JSONValue], b: [JSONValue],
                                  aVal: JSONValue, bVal: JSONValue) -> DiffNode {
        var children: [DiffNode] = []
        let shared = min(a.count, b.count)
        for i in 0..<shared {
            children.append(diff(label: "[\(i)]", a: a[i], b: b[i]))
        }
        if a.count > b.count {
            for i in shared..<a.count {
                children.append(DiffNode(label: "[\(i)]", status: .removed, kind: kind(of: a[i]),
                                         oldValue: a[i], newValue: nil, children: []))
            }
        } else if b.count > a.count {
            for i in shared..<b.count {
                children.append(DiffNode(label: "[\(i)]", status: .added, kind: kind(of: b[i]),
                                         oldValue: nil, newValue: b[i], children: []))
            }
        }

        let differs = children.contains { $0.status != .unchanged }
        return DiffNode(label: label, status: differs ? .changed : .unchanged,
                        kind: .array, oldValue: aVal, newValue: bVal, children: children)
    }

    // MARK: - Scalar equality

    private static func scalarsEqual(_ a: JSONValue, _ b: JSONValue) -> Bool {
        switch (a, b) {
        case let (.string(x), .string(y)):
            return x == y
        case let (.bool(x), .bool(y)):
            return x == y
        case (.null, .null):
            return true
        case let (.number(x), .number(y)):
            return numbersEqual(x, y)
        default:
            // Different scalar types (e.g. string vs number) -> not equal.
            return false
        }
    }

    // MARK: - Number equality (arbitrary precision, exact)

    /// True iff two JSON number literals denote the same mathematical value.
    /// Compares by canonical decimal value WITHOUT going through Double, so it
    /// is exact for integers beyond Double's 53-bit mantissa.
    /// The parser has already validated these are well-formed JSON numbers.
    private static func numbersEqual(_ a: String, _ b: String) -> Bool {
        // Fast path: identical literals.
        if a == b { return true }
        guard let na = canonicalize(a), let nb = canonicalize(b) else {
            // Should not happen for parser-validated numbers; fall back to raw.
            return a == b
        }
        return na == nb
    }

    /// Canonical fixed-point form of a JSON number literal:
    /// (negative, integer-digits, fraction-digits). Zero is normalized to
    /// (false, "0", "") regardless of sign or exponent.
    private static func canonicalize(_ s: String) -> (negative: Bool, intPart: String, fracPart: String)? {
        let chars = Array(s)
        var i = 0
        let n = chars.count

        var negative = false
        if i < n, chars[i] == "-" {
            negative = true
            i += 1
        } else if i < n, chars[i] == "+" {
            i += 1
        }

        // Integer part digits.
        var intDigits = ""
        while i < n, chars[i].isNumber {
            intDigits.append(chars[i])
            i += 1
        }

        // Fraction part digits.
        var fracDigits = ""
        if i < n, chars[i] == "." {
            i += 1
            while i < n, chars[i].isNumber {
                fracDigits.append(chars[i])
                i += 1
            }
        }

        // Exponent.
        var exp = 0
        if i < n, chars[i] == "e" || chars[i] == "E" {
            i += 1
            var expNeg = false
            if i < n, chars[i] == "+" {
                i += 1
            } else if i < n, chars[i] == "-" {
                expNeg = true
                i += 1
            }
            var expDigits = ""
            while i < n, chars[i].isNumber {
                expDigits.append(chars[i])
                i += 1
            }
            guard let e = Int(expDigits) else { return nil }
            exp = expNeg ? -e : e
        }

        // Reject if there are leftover characters (malformed).
        if i != n { return nil }

        // Combine all significant digits into one sequence, tracking the
        // position of the decimal point relative to the END of that sequence.
        // value = digits * 10^(-fracCount) * 10^exp
        let digits = intDigits + fracDigits
        // Net decimal point shift from the right of `digits`.
        let pointFromRight = fracDigits.count - exp

        // Split `digits` into integer and fraction at `pointFromRight`.
        var intResult: String
        var fracResult: String
        if pointFromRight <= 0 {
            // Decimal point is at or beyond the right end: append zeros.
            intResult = digits + String(repeating: "0", count: -pointFromRight)
            fracResult = ""
        } else if pointFromRight >= digits.count {
            // Decimal point is at or beyond the left end: pad with leading zeros.
            let pad = pointFromRight - digits.count
            intResult = ""
            fracResult = String(repeating: "0", count: pad) + digits
        } else {
            let splitIndex = digits.count - pointFromRight
            let arr = Array(digits)
            intResult = String(arr[0..<splitIndex])
            fracResult = String(arr[splitIndex...])
        }

        // Strip leading zeros from integer part.
        while intResult.count > 1, intResult.hasPrefix("0") {
            intResult.removeFirst()
        }
        if intResult.isEmpty { intResult = "0" }
        // Strip trailing zeros from fraction part.
        while fracResult.hasSuffix("0") {
            fracResult.removeLast()
        }

        // Normalize negative zero.
        if intResult == "0", fracResult.isEmpty {
            negative = false
        }

        return (negative, intResult, fracResult)
    }
}
