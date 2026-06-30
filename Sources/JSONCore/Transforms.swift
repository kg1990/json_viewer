// Transforms.swift
// Pure, deterministic text-transform engine: JSON string escaping, base64,
// percent-encoding, and REAL gzip (via zlib). Zero UI dependencies.

import Foundation
import zlib

public struct TransformError: Error, Equatable, CustomStringConvertible {
    public let message: String
    public init(_ m: String) { message = m }
    public var description: String { message }
}

public enum Transforms {

    // MARK: - JSON string escaping

    /// Escape a string for use as the contents of a JSON string literal.
    /// Does NOT add surrounding quotes and does NOT escape `/`.
    public static func jsonEscape(_ s: String) -> String {
        var out = String()
        out.reserveCapacity(s.count)
        for scalar in s.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\t": out += "\\t"
            case "\r": out += "\\r"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out
    }

    /// Decode a JSON string. If `s` (length >= 2) starts AND ends with a double
    /// quote, both outer quotes are stripped first; then escapes are decoded.
    public static func jsonUnescape(_ s: String) throws -> String {
        var body = s
        if body.count >= 2, body.hasPrefix("\""), body.hasSuffix("\"") {
            body = String(body.dropFirst().dropLast())
        }
        return try decodeEscapes(body)
    }

    /// Decode escape sequences without stripping any outer quotes.
    public static func stringUnescape(_ s: String) throws -> String {
        return try decodeEscapes(s)
    }

    /// Shared escape decoder for jsonUnescape / stringUnescape.
    private static func decodeEscapes(_ s: String) throws -> String {
        let scalars = Array(s.unicodeScalars)
        var result = String.UnicodeScalarView()
        var i = 0
        let n = scalars.count
        while i < n {
            let c = scalars[i]
            if c != "\\" {
                result.append(c)
                i += 1
                continue
            }
            // c == backslash
            i += 1
            if i >= n { throw TransformError("dangling escape backslash") }
            let e = scalars[i]
            switch e {
            case "\"": result.append("\""); i += 1
            case "\\": result.append("\\"); i += 1
            case "/": result.append("/"); i += 1
            case "n": result.append("\n"); i += 1
            case "t": result.append("\t"); i += 1
            case "r": result.append("\r"); i += 1
            case "b": result.append("\u{08}"); i += 1
            case "f": result.append("\u{0C}"); i += 1
            case "u":
                // need 4 hex digits after the 'u'
                let hi = try readHex4(scalars, after: i, n: n)
                i += 5 // consumed 'u' + 4 hex
                if hi >= 0xD800 && hi <= 0xDBFF {
                    // high surrogate — require a following \uXXXX low surrogate
                    guard i + 1 < n, scalars[i] == "\\", scalars[i + 1] == "u" else {
                        throw TransformError("high surrogate not followed by \\u low surrogate")
                    }
                    let lo = try readHex4(scalars, after: i + 1, n: n)
                    guard lo >= 0xDC00 && lo <= 0xDFFF else {
                        throw TransformError("invalid low surrogate")
                    }
                    i += 6 // consumed '\' 'u' + 4 hex
                    let combined = 0x10000 + ((hi - 0xD800) << 10) + (lo - 0xDC00)
                    guard let us = Unicode.Scalar(combined) else {
                        throw TransformError("invalid combined surrogate scalar")
                    }
                    result.append(us)
                } else if hi >= 0xDC00 && hi <= 0xDFFF {
                    throw TransformError("lone low surrogate")
                } else {
                    guard let us = Unicode.Scalar(hi) else {
                        throw TransformError("invalid unicode scalar")
                    }
                    result.append(us)
                }
            default:
                throw TransformError("unknown escape: \\\(e)")
            }
        }
        return String(result)
    }

    /// Read exactly 4 hex digits located at indices (start+1 ... start+4),
    /// where `start` is the index of the 'u'. Returns the integer value.
    private static func readHex4(_ scalars: [Unicode.Scalar], after start: Int, n: Int) throws -> Int {
        guard start + 4 < n else { throw TransformError("malformed \\u: not enough digits") }
        var value = 0
        var k = start + 1
        while k <= start + 4 {
            guard let d = hexDigit(scalars[k]) else {
                throw TransformError("malformed \\u: non-hex digit")
            }
            value = value * 16 + d
            k += 1
        }
        return value
    }

    private static func hexDigit(_ s: Unicode.Scalar) -> Int? {
        switch s {
        case "0"..."9": return Int(s.value - 0x30)
        case "a"..."f": return Int(s.value - 0x61 + 10)
        case "A"..."F": return Int(s.value - 0x41 + 10)
        default: return nil
        }
    }

    // MARK: - Base64

    public static func base64Encode(_ s: String) -> String {
        return Data(s.utf8).base64EncodedString()
    }

    public static func base64Decode(_ s: String) throws -> String {
        guard let data = Data(base64Encoded: s) else {
            throw TransformError("invalid base64")
        }
        guard let str = String(data: data, encoding: .utf8) else {
            throw TransformError("base64 bytes are not valid UTF-8")
        }
        return str
    }

    // MARK: - URL percent-encoding

    private static let unreserved: Set<UInt8> = {
        var set = Set<UInt8>()
        for b in UInt8(ascii: "A")...UInt8(ascii: "Z") { set.insert(b) }
        for b in UInt8(ascii: "a")...UInt8(ascii: "z") { set.insert(b) }
        for b in UInt8(ascii: "0")...UInt8(ascii: "9") { set.insert(b) }
        for c in "-_.~".utf8 { set.insert(c) }
        return set
    }()

    public static func urlEscape(_ s: String) -> String {
        var out = String()
        for byte in s.utf8 {
            if unreserved.contains(byte) {
                out.unicodeScalars.append(Unicode.Scalar(byte))
            } else {
                out += String(format: "%%%02X", byte)
            }
        }
        return out
    }

    public static func urlUnescape(_ s: String) throws -> String {
        let scalars = Array(s.unicodeScalars)
        var bytes = [UInt8]()
        var i = 0
        let n = scalars.count
        while i < n {
            let c = scalars[i]
            if c == "%" {
                guard i + 2 < n,
                      let hi = hexDigit(scalars[i + 1]),
                      let lo = hexDigit(scalars[i + 2]) else {
                    throw TransformError("malformed percent-escape")
                }
                bytes.append(UInt8(hi * 16 + lo))
                i += 3
            } else {
                // Re-encode the literal scalar to UTF-8 bytes.
                guard c.value < 0x80 else {
                    // Non-ASCII literal: encode its UTF-8 representation.
                    for b in String(c).utf8 { bytes.append(b) }
                    i += 1
                    continue
                }
                bytes.append(UInt8(c.value))
                i += 1
            }
        }
        guard let str = String(bytes: bytes, encoding: .utf8) else {
            throw TransformError("percent-decoded bytes are not valid UTF-8")
        }
        return str
    }

    // MARK: - Gzip (real, via zlib)

    public static func gzipBase64Encode(_ s: String) throws -> String {
        let input = Array(s.utf8)
        let compressed = try gzipDeflate(input)
        return Data(compressed).base64EncodedString()
    }

    public static func base64GunzipDecode(_ s: String) throws -> String {
        guard let data = Data(base64Encoded: s) else {
            throw TransformError("invalid base64")
        }
        let inflated = try gzipInflate([UInt8](data))
        guard let str = String(bytes: inflated, encoding: .utf8) else {
            throw TransformError("gunzipped bytes are not valid UTF-8")
        }
        return str
    }

    /// Compress bytes into a real gzip stream (windowBits = 31).
    private static func gzipDeflate(_ input: [UInt8]) throws -> [UInt8] {
        var strm = z_stream()
        let initResult = deflateInit2_(
            &strm,
            Z_DEFAULT_COMPRESSION,
            Z_DEFLATED,
            31,            // 15 window | 16 gzip wrapper
            8,             // mem level
            Z_DEFAULT_STRATEGY,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        guard initResult == Z_OK else {
            throw TransformError("deflateInit2 failed: \(initResult)")
        }
        defer { deflateEnd(&strm) }

        var output = [UInt8]()
        let chunkSize = 16384
        var chunk = [UInt8](repeating: 0, count: chunkSize)

        var inputCopy = input
        let status: Int32 = inputCopy.withUnsafeMutableBufferPointer { inPtr -> Int32 in
            strm.next_in = inPtr.baseAddress
            strm.avail_in = uInt(inPtr.count)
            var rc: Int32 = Z_OK
            repeat {
                rc = chunk.withUnsafeMutableBufferPointer { outPtr -> Int32 in
                    strm.next_out = outPtr.baseAddress
                    strm.avail_out = uInt(outPtr.count)
                    let r = deflate(&strm, Z_FINISH)
                    let produced = outPtr.count - Int(strm.avail_out)
                    if produced > 0 {
                        output.append(contentsOf: outPtr[0..<produced])
                    }
                    return r
                }
                if rc == Z_STREAM_ERROR { return rc }
            } while rc != Z_STREAM_END
            return rc
        }

        guard status == Z_STREAM_END else {
            throw TransformError("deflate failed: \(status)")
        }
        return output
    }

    /// Decompress a gzip (or zlib) stream (windowBits = 47 auto-detect).
    private static func gzipInflate(_ input: [UInt8]) throws -> [UInt8] {
        guard !input.isEmpty else {
            throw TransformError("empty input is not a gzip stream")
        }
        var strm = z_stream()
        let initResult = inflateInit2_(
            &strm,
            47,            // 15 window | 32 auto-detect zlib/gzip header
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        guard initResult == Z_OK else {
            throw TransformError("inflateInit2 failed: \(initResult)")
        }
        defer { inflateEnd(&strm) }

        var output = [UInt8]()
        let chunkSize = 16384
        var chunk = [UInt8](repeating: 0, count: chunkSize)

        var inputCopy = input
        let status: Int32 = inputCopy.withUnsafeMutableBufferPointer { inPtr -> Int32 in
            strm.next_in = inPtr.baseAddress
            strm.avail_in = uInt(inPtr.count)
            var rc: Int32 = Z_OK
            repeat {
                rc = chunk.withUnsafeMutableBufferPointer { outPtr -> Int32 in
                    strm.next_out = outPtr.baseAddress
                    strm.avail_out = uInt(outPtr.count)
                    let r = inflate(&strm, Z_NO_FLUSH)
                    let produced = outPtr.count - Int(strm.avail_out)
                    if produced > 0 {
                        output.append(contentsOf: outPtr[0..<produced])
                    }
                    return r
                }
                if rc == Z_STREAM_END { break }
                if rc != Z_OK { return rc }
                // rc == Z_OK: keep going only while there is input left or
                // the last chunk filled completely (more output pending).
                if strm.avail_in == 0 && strm.avail_out != 0 {
                    break
                }
            } while true
            return rc
        }

        guard status == Z_STREAM_END else {
            throw TransformError("inflate failed / not a valid gzip stream: \(status)")
        }
        return output
    }
}
