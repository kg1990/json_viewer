// TestMain.swift
// Plain-Swift test runner for JSONCore (no XCTest — XCTest is unavailable in
// the CLT-only SDK here). Ports every assertion from the XCTest suites into a
// tiny assert harness.

import Foundation

// MARK: - Assert harness

var checksRun = 0
var failures = 0

func check(_ cond: Bool, _ msg: String) {
    checksRun += 1
    if !cond {
        failures += 1
        print("FAIL: \(msg)")
    }
}

func checkEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String) {
    checksRun += 1
    if a != b {
        failures += 1
        print("FAIL: \(msg) — expected \(b), got \(a)")
    }
}

func checkThrows<T>(_ expr: @autoclosure () throws -> T, _ msg: String) {
    checksRun += 1
    do {
        _ = try expr()
        failures += 1
        print("FAIL: \(msg) — expected throw, but succeeded")
    } catch {
        // expected
    }
}

func checkNoThrow<T>(_ expr: @autoclosure () throws -> T, _ msg: String) -> T? {
    do {
        return try expr()
    } catch {
        checksRun += 1
        failures += 1
        print("FAIL: \(msg) — unexpected throw: \(error)")
        return nil
    }
}

// MARK: - Parser tests

func runParserTests() {
    // testParseEmptyObjectAndArray
    checkEqual(checkNoThrow(try JSONParser.parse("{}"), "parse {}"), .object([]), "empty object")
    checkEqual(checkNoThrow(try JSONParser.parse("[]"), "parse []"), .array([]), "empty array")

    // testParsePrimitives
    checkEqual(checkNoThrow(try JSONParser.parse("true"), "parse true"), .bool(true), "bool true")
    checkEqual(checkNoThrow(try JSONParser.parse("false"), "parse false"), .bool(false), "bool false")
    checkEqual(checkNoThrow(try JSONParser.parse("null"), "parse null"), .null, "null")
    checkEqual(checkNoThrow(try JSONParser.parse("\"hi\""), "parse \"hi\""), .string("hi"), "string hi")

    // testNumbersStoredAsRawLiteral
    checkEqual(checkNoThrow(try JSONParser.parse("1"), "parse 1"), .number("1"), "number 1")
    checkEqual(checkNoThrow(try JSONParser.parse("1.0"), "parse 1.0"), .number("1.0"), "number 1.0")
    checkEqual(checkNoThrow(try JSONParser.parse("-42"), "parse -42"), .number("-42"), "number -42")
    checkEqual(checkNoThrow(try JSONParser.parse("3.14e10"), "parse 3.14e10"), .number("3.14e10"), "number 3.14e10")
    checkEqual(checkNoThrow(try JSONParser.parse("-0.5E-3"), "parse -0.5E-3"), .number("-0.5E-3"), "number -0.5E-3")
    checkEqual(checkNoThrow(try JSONParser.parse("0"), "parse 0"), .number("0"), "number 0")

    // testKeyOrderPreserved
    if let v = checkNoThrow(try JSONParser.parse("{\"b\":1,\"a\":2,\"c\":3}"), "parse key-order object") {
        guard case .object(let pairs) = v else {
            check(false, "key-order: expected object")
            return
        }
        checkEqual(pairs.map { $0.0 }, ["b", "a", "c"], "key order preserved")
    }

    // testEscapedStrings
    checkEqual(checkNoThrow(try JSONParser.parse("\"a\\\"b\\\\c\\n\\t\\r\\b\\f\\/d\""), "parse escaped string"),
               .string("a\"b\\c\n\t\r\u{08}\u{0C}/d"), "escaped string decode")

    // testUnicodeEscapeBMP
    checkEqual(checkNoThrow(try JSONParser.parse("\"\\u00e9\""), "parse \\u00e9"), .string("é"), "BMP unicode escape")

    // testUnicodeSurrogatePair
    checkEqual(checkNoThrow(try JSONParser.parse("\"\\uD83D\\uDE00\""), "parse surrogate pair"), .string("😀"), "surrogate pair")

    // testNestedStructure
    checkEqual(checkNoThrow(try JSONParser.parse("{\"a\":[1,{\"b\":null},[true]]}"), "parse nested"),
               .object([("a", .array([.number("1"), .object([("b", .null)]), .array([.bool(true)])]))]),
               "nested structure")

    // testRawUnicodeInString
    checkEqual(checkNoThrow(try JSONParser.parse("\"héllo 世界\""), "parse raw unicode"), .string("héllo 世界"), "raw unicode in string")

    // Invalid cases
    checkThrows(try JSONParser.parse("01"), "leading zero rejected")
    checkThrows(try JSONParser.parse("\"\\uDE00\""), "lone low surrogate rejected")
    checkThrows(try JSONParser.parse("\"a\u{01}b\""), "control char in string rejected")
}

// MARK: - Formatter tests

func runFormatterTests() {
    // testPrettyTwoSpaces
    let expected2 = """
    {
      "a": 1,
      "b": [
        2,
        3
      ]
    }
    """
    checkEqual(checkNoThrow(try JSONFormatter.prettyPrint("{\"a\":1,\"b\":[2,3]}", indent: .spaces(2)), "pretty 2sp"),
               expected2, "pretty 2 spaces")

    // testPrettyFourSpaces
    checkEqual(checkNoThrow(try JSONFormatter.prettyPrint("{\"a\":1}", indent: .spaces(4)), "pretty 4sp"),
               "{\n    \"a\": 1\n}", "pretty 4 spaces")

    // testPrettyTab
    checkEqual(checkNoThrow(try JSONFormatter.prettyPrint("{\"a\":1}", indent: .tab), "pretty tab"),
               "{\n\t\"a\": 1\n}", "pretty tab")

    // testPrettyKeyOrderPreserved
    if let out = checkNoThrow(try JSONFormatter.prettyPrint("{\"z\":1,\"a\":2,\"m\":3}", indent: .spaces(2)), "pretty key-order") {
        let zPos = out.range(of: "\"z\"")!.lowerBound
        let aPos = out.range(of: "\"a\"")!.lowerBound
        let mPos = out.range(of: "\"m\"")!.lowerBound
        check(zPos < aPos && aPos < mPos, "pretty key order preserved")
    }

    // testPrettyEmptyContainers
    checkEqual(checkNoThrow(try JSONFormatter.prettyPrint("{}"), "pretty {}"), "{}", "pretty empty object")
    checkEqual(checkNoThrow(try JSONFormatter.prettyPrint("[]"), "pretty []"), "[]", "pretty empty array")
    checkEqual(checkNoThrow(try JSONFormatter.prettyPrint("{\"a\":{},\"b\":[]}", indent: .spaces(2)), "pretty empty containers"),
               "{\n  \"a\": {},\n  \"b\": []\n}", "pretty nested empty containers")

    // testPrettyOutputReParses
    if let pretty = checkNoThrow(try JSONFormatter.prettyPrint("{\"a\":[1,{\"b\":\"x y\"},null],\"c\":true}", indent: .spaces(2)), "pretty reparse fmt"),
       let reparsed = checkNoThrow(try JSONParser.parse(pretty), "pretty reparse parse"),
       let orig = checkNoThrow(try JSONParser.parse("{\"a\":[1,{\"b\":\"x y\"},null],\"c\":true}"), "pretty reparse orig") {
        checkEqual(reparsed, orig, "pretty output re-parses equal")
    }

    // testPrettyNested
    if let pretty = checkNoThrow(try JSONFormatter.prettyPrint("{\"a\":{\"b\":{\"c\":[1,2]}}}", indent: .spaces(2)), "pretty nested fmt"),
       let reparsed = checkNoThrow(try JSONParser.parse(pretty), "pretty nested parse"),
       let orig = checkNoThrow(try JSONParser.parse("{\"a\":{\"b\":{\"c\":[1,2]}}}"), "pretty nested orig") {
        checkEqual(reparsed, orig, "pretty nested re-parses equal")
        check(pretty.contains("      \"c\""), "pretty nested indentation depth")
    }

    // testMinifyStripsWhitespace
    let minInput = """
    {
      "a": 1,
      "b": [ 2, 3 ]
    }
    """
    checkEqual(checkNoThrow(try JSONFormatter.minify(minInput), "minify ws"), "{\"a\":1,\"b\":[2,3]}", "minify strips whitespace")

    // testMinifyRoundTrip
    if let minified = checkNoThrow(try JSONFormatter.minify("{\"a\":[1,2,3],\"b\":{\"c\":null}}"), "minify rt fmt"),
       let rp = checkNoThrow(try JSONParser.parse(minified), "minify rt parse"),
       let orig = checkNoThrow(try JSONParser.parse("{\"a\":[1,2,3],\"b\":{\"c\":null}}"), "minify rt orig") {
        checkEqual(rp, orig, "minify round-trip equal")
    }

    // testMinifyPreservesSpacesInsideStrings
    checkEqual(checkNoThrow(try JSONFormatter.minify("{ \"k\" : \"hello   world\" }"), "minify spaces"),
               "{\"k\":\"hello   world\"}", "minify preserves spaces in strings")

    // testMinifyNumberRoundTrip
    checkEqual(checkNoThrow(try JSONFormatter.minify("[1, 1.0, -0.5E-3, 3.14e10]"), "minify num"),
               "[1,1.0,-0.5E-3,3.14e10]", "minify number round-trip")

    // testIntegerHasNoTrailingDotZero
    checkEqual(checkNoThrow(try JSONFormatter.minify("1"), "minify int 1"), "1", "integer no trailing .0")
    checkEqual(checkNoThrow(try JSONFormatter.minify("[1,2,3]"), "minify int arr"), "[1,2,3]", "integer array no trailing .0")

    // testEscapingRoundTripsThroughMinify
    if let minified = checkNoThrow(try JSONFormatter.minify("\"line1\\nline2\\t\\\"q\\\"\""), "minify esc fmt"),
       let rp = checkNoThrow(try JSONParser.parse(minified), "minify esc parse"),
       let orig = checkNoThrow(try JSONParser.parse("\"line1\\nline2\\t\\\"q\\\"\""), "minify esc orig") {
        checkEqual(rp, orig, "escaping round-trips through minify")
    }
}

// MARK: - Validator tests

func runValidatorTests() {
    // testValidInput
    checkEqual(JSONValidator.validate("{\"a\":[1,2,3]}"), .valid, "validate valid input")

    // testValidNestedInput
    checkEqual(JSONValidator.validate("{\"a\":{\"b\":null},\"c\":[true,false]}"), .valid, "validate valid nested input")

    // testTrailingCommaInvalidWithPosition
    if case .invalid(let e) = JSONValidator.validate("{\"a\":1,}") {
        checkEqual(e.line, 1, "trailing comma line")
        check(e.column > 0, "trailing comma column > 0")
        check(e.message.lowercased().contains("trailing comma"), "trailing comma message")
    } else {
        check(false, "trailing comma should be invalid")
    }

    // testUnclosedBraceInvalidWithPosition
    if case .invalid(let e) = JSONValidator.validate("{\"a\":1") {
        checkEqual(e.line, 1, "unclosed brace line")
        check(e.column > 0, "unclosed brace column > 0")
        check(!e.message.isEmpty, "unclosed brace message non-empty")
    } else {
        check(false, "unclosed brace should be invalid")
    }

    // testBadTokenInvalidWithPosition
    if case .invalid(let e) = JSONValidator.validate("{\"a\": tru}") {
        checkEqual(e.line, 1, "bad token line")
        check(e.column > 0, "bad token column > 0")
        check(!e.message.isEmpty, "bad token message non-empty")
    } else {
        check(false, "bad token should be invalid")
    }

    // testLineNumberOnMultilineInput
    let multiline = "{\n  \"a\": 1,\n  \"b\": @\n}"
    if case .invalid(let e) = JSONValidator.validate(multiline) {
        checkEqual(e.line, 3, "multiline error line")
        check(e.column > 0, "multiline error column > 0")
    } else {
        check(false, "multiline bad value should be invalid")
    }

    // testEmptyInputInvalid
    if case .invalid = JSONValidator.validate("   ") {
        check(true, "empty input invalid")
    } else {
        check(false, "empty input should be invalid")
    }

    // testTrailingCharactersInvalid
    if case .invalid = JSONValidator.validate("{} extra") {
        check(true, "trailing characters invalid")
    } else {
        check(false, "trailing characters should be invalid")
    }
}

// MARK: - JSONPath tests

func runJSONPathTests() {
    // testWildcardOverArrayOfObjectsOrderPreserved
    checkEqual(checkNoThrow(try JSONPath.extract("$[*].id", from: "[{\"id\":3},{\"id\":1},{\"id\":2}]"), "wildcard order"),
               [.number("3"), .number("1"), .number("2")], "$[*].id order preserved")

    // testMissingKeySkipped
    checkEqual(checkNoThrow(try JSONPath.extract("$[*].id", from: "[{\"id\":1},{\"name\":\"x\"},{\"id\":3}]"), "missing key"),
               [.number("1"), .number("3")], "missing key skipped")

    // testUsersEmailPath
    checkEqual(checkNoThrow(try JSONPath.extract("$.users[*].email", from: "{\"users\":[{\"email\":\"a@x\"},{\"email\":\"b@x\"}]}"), "users email"),
               [.string("a@x"), .string("b@x")], "$.users[*].email")

    // testNestedWildcard
    checkEqual(checkNoThrow(try JSONPath.extract("$.a.b[*].x", from: "{\"a\":{\"b\":[{\"x\":1},{\"x\":2}]}}"), "nested wildcard"),
               [.number("1"), .number("2")], "nested wildcard")

    // testArrayIndex
    checkEqual(checkNoThrow(try JSONPath.extract("$[0].name", from: "[{\"name\":\"first\"},{\"name\":\"second\"}]"), "array index"),
               [.string("first")], "[index] access")

    // testBareLeadingKeyNoDollar
    checkEqual(checkNoThrow(try JSONPath.extract("data.items[*].id", from: "{\"data\":{\"items\":[{\"id\":1},{\"id\":2}]}}"), "bare leading key"),
               [.number("1"), .number("2")], "bare leading key no $")

    // testNoMatchReturnsEmpty
    checkEqual(checkNoThrow(try JSONPath.extract("$.b.c", from: "{\"a\":1}"), "no match"),
               [], "no-match returns empty")

    // testBracketQuotedKey
    checkEqual(checkNoThrow(try JSONPath.extract("$['weird key']", from: "{\"weird key\":42}"), "quoted key"),
               [.number("42")], "bracket quoted key")

    // testIndexOutOfRangeReturnsEmpty
    checkEqual(checkNoThrow(try JSONPath.extract("$[5]", from: "[1,2]"), "oob index"),
               [], "index out of range returns empty")

    // testRootDollarReturnsWholeDocument
    checkEqual(checkNoThrow(try JSONPath.extract("$", from: "{\"a\":1}"), "root $"),
               [.object([("a", .number("1"))])], "root $ whole document")

    // testWildcardOnNonArraySkipped
    checkEqual(checkNoThrow(try JSONPath.extract("$.a[*]", from: "{\"a\":1}"), "wildcard non-array"),
               [], "wildcard on non-array skipped")

    // testDeepNestedWildcardThenIndex
    checkEqual(checkNoThrow(try JSONPath.extract("$.rows[*].cells[1]", from: "{\"rows\":[{\"cells\":[10,11]},{\"cells\":[20,21]}]}"), "deep nested wildcard index"),
               [.number("11"), .number("21")], "deep nested wildcard then index")
}

// MARK: - Transforms tests

func runTransformsTests() {
    // AC-3 base64
    checkEqual(Transforms.base64Encode("hello"), "aGVsbG8=", "base64 hello")
    // round-trip ASCII / Chinese / emoji
    for s in ["hello", "", "ascii 123 !@#", "你好世界", "😀🚀✨", "混合 mixed 文字 😀"] {
        let enc = Transforms.base64Encode(s)
        checkEqual(checkNoThrow(try Transforms.base64Decode(enc), "b64 decode \(s)"), s, "base64 round-trip \(s)")
    }

    // AC-4 url
    checkEqual(Transforms.urlEscape("a b&c"), "a%20b%26c", "urlEscape a b&c")
    for s in ["a b&c", "", "plain", "你好 世界", "a=1&b=2 c/d?e#f", "tilde~dash-dot.under_"] {
        let enc = Transforms.urlEscape(s)
        checkEqual(checkNoThrow(try Transforms.urlUnescape(enc), "url decode \(s)"), s, "url round-trip \(s)")
    }
    // unreserved chars stay literal
    checkEqual(Transforms.urlEscape("AZaz09-_.~"), "AZaz09-_.~", "url unreserved untouched")
    checkThrows(try Transforms.urlUnescape("%2"), "urlUnescape %2 throws")
    checkThrows(try Transforms.urlUnescape("%GG"), "urlUnescape %GG throws")
    checkThrows(try Transforms.urlUnescape("abc%"), "urlUnescape trailing % throws")
    // case-insensitive hex decode
    checkEqual(checkNoThrow(try Transforms.urlUnescape("%2f%2F"), "url ci hex"), "//", "url case-insensitive hex")

    // AC-5 json escape / unescape
    checkEqual(Transforms.jsonEscape("a\"b\n"), "a\\\"b\\n", "jsonEscape a\"b\\n")
    // do not escape slash
    checkEqual(Transforms.jsonEscape("a/b"), "a/b", "jsonEscape leaves slash")
    // control char < 0x20 -> \uXXXX
    checkEqual(Transforms.jsonEscape("\u{01}"), "\\u0001", "jsonEscape control char")
    // all special escapes
    checkEqual(Transforms.jsonEscape("\\\t\r\u{08}\u{0C}"), "\\\\\\t\\r\\b\\f", "jsonEscape specials")
    for s in ["a\"b\n", "", "plain text", "tab\there", "ctrl\u{01}\u{1f}end", "你好\n世界", "emoji 😀 end", "back\\slash"] {
        let esc = Transforms.jsonEscape(s)
        checkEqual(checkNoThrow(try Transforms.jsonUnescape(esc), "jsonUnescape \(s)"), s, "jsonEscape/Unescape round-trip \(s)")
    }
    // AC-5 quote stripping
    checkEqual(checkNoThrow(try Transforms.jsonUnescape("\"hi\""), "jsonUnescape quoted"), "hi", "jsonUnescape strips outer quotes")
    // surrogate pair decode
    checkEqual(checkNoThrow(try Transforms.jsonUnescape("\\uD83D\\uDE00"), "jsonUnescape surrogate"), "😀", "jsonUnescape surrogate pair")

    // AC-6 string unescape
    checkEqual(checkNoThrow(try Transforms.stringUnescape("\\u0041"), "stringUnescape u0041"), "A", "stringUnescape \\u0041 == A")
    // jsonUnescape strips quotes; stringUnescape does NOT
    checkEqual(checkNoThrow(try Transforms.jsonUnescape("\"hi\""), "jsonUnescape quoted2"), "hi", "jsonUnescape -> hi")
    checkEqual(checkNoThrow(try Transforms.stringUnescape("\"hi\""), "stringUnescape quoted2"), "\"hi\"", "stringUnescape -> \"hi\"")
    // unknown escape / malformed \u throw (both functions share decoder)
    checkThrows(try Transforms.stringUnescape("\\x"), "stringUnescape unknown escape throws")
    checkThrows(try Transforms.jsonUnescape("\\u12"), "jsonUnescape malformed \\u throws")
    checkThrows(try Transforms.stringUnescape("\\uZZZZ"), "stringUnescape non-hex \\u throws")
    checkThrows(try Transforms.stringUnescape("\\uD83D"), "stringUnescape lone high surrogate throws")
    checkThrows(try Transforms.stringUnescape("\\uDE00"), "stringUnescape lone low surrogate throws")

    // AC-7 gzip round-trip
    checkEqual(checkNoThrow(try Transforms.base64GunzipDecode(checkNoThrow(try Transforms.gzipBase64Encode("hello"), "gzip hello") ?? ""), "gunzip hello"),
               "hello", "gzip round-trip hello")
    for s in ["", "a", "hello world", "你好世界 gzip 测试 😀"] {
        if let enc = checkNoThrow(try Transforms.gzipBase64Encode(s), "gzip enc \(s)") {
            checkEqual(checkNoThrow(try Transforms.base64GunzipDecode(enc), "gzip dec \(s)"), s, "gzip round-trip \(s)")
        }
    }

    // AC-8 long text (5KB) + Chinese
    let long = String(repeating: "The quick brown fox 你好 😀 1234567890\n", count: 150)
    check(long.utf8.count >= 5000, "long text >= 5KB")
    if let enc = checkNoThrow(try Transforms.gzipBase64Encode(long), "gzip long enc") {
        checkEqual(checkNoThrow(try Transforms.base64GunzipDecode(enc), "gzip long dec"), long, "gzip round-trip long text")
    }
    let chinese = String(repeating: "测试中文压缩内容。", count: 300)
    if let enc = checkNoThrow(try Transforms.gzipBase64Encode(chinese), "gzip chinese enc") {
        checkEqual(checkNoThrow(try Transforms.base64GunzipDecode(enc), "gzip chinese dec"), chinese, "gzip round-trip chinese")
    }

    // AC-9 errors
    checkThrows(try Transforms.base64Decode("not valid base64!!!"), "invalid base64 throws")
    checkThrows(try Transforms.urlUnescape("%ZZ"), "invalid percent throws")
    checkThrows(try Transforms.base64GunzipDecode(Transforms.base64Encode("this is plainly not gzip")), "non-gzip bytes throw")
    checkThrows(try Transforms.base64GunzipDecode("@@not base64@@"), "gunzip invalid base64 throws")
}

// MARK: - main

runParserTests()
runFormatterTests()
runValidatorTests()
runJSONPathTests()
runTransformsTests()

print("RAN \(checksRun) checks, \(failures) failures")
exit(failures == 0 ? 0 : 1)
