# JSON Viewer

A native macOS JSON tool built with SwiftUI on top of the `JSONCore` library.

## What it does

A two-pane window: edit JSON on the left, see formatted output on the right.

- **Beautify** — pretty-print the input using the selected indent style.
- **Minify** — collapse the input to a single compact line.
- **Validate** — check the input and show a clear inline status: green "Valid JSON",
  or red `line L, column C: message` on a parse error.
- **Clear** — empty both panes.
- **Indent picker** — 2 Spaces / 4 Spaces / Tab, applied to Beautify and to
  extraction results.
- Beautify/Minify on invalid input shows the parse error instead of garbage output.

### Extraction

Enter a path in the **Path** field and press **Extract** (or Cmd+Return). Results
open in a **separate window** showing the pretty-printed matches and a count of
extracted items. The result window has:

- **Copy** — copies the result text to the clipboard.
- **Download** — saves the result to a `.json` (or `.txt`) file.

Bad paths or invalid JSON show the error in the result window instead of crashing.

#### Path syntax

A JSONPath subset over the ordered JSON model:

- optional leading `$`
- `.key` — object member access
- `['key']` / `["key"]` — quoted object member access
- `[<integer>]` — array index access (negative indices count from the end)
- `[*]` — wildcard over array elements

chained arbitrarily. Missing keys, out-of-range indices, and type mismatches are
skipped (never crash).

Examples:

```
$[*].id
.data.items[0]
['key']
$.users[*].name
$.items[-1]
```

## Build

This project targets a Command Line Tools-only environment. **SwiftPM
(`swift build` / `swift test`) and `xcodebuild` are not used** — everything is
compiled with `swiftc` directly.

```sh
./build_lib.sh    # compile JSONCore into build/libJSONCore.dylib
./run_tests.sh    # run the JSONCore test suite
./build_app.sh    # compile + bundle build/JSONViewer.app
```

`build_app.sh` compiles `JSONCore` + the SwiftUI app with
`swiftc -parse-as-library`, writes the `Info.plist`, lints it with
`plutil -lint`, and prints the `.app` path. It exits non-zero on compile failure.

## Run

```sh
open build/JSONViewer.app
```

The app is **unsigned**, so on first launch macOS Gatekeeper will block it.
Right-click the app → **Open**, then confirm in the dialog. Subsequent launches
work normally.

## Constraint

Built and verified on macOS 14.4 (arm64) with Swift 5.9 Command Line Tools only.
No Xcode, no SwiftPM build/test — `swiftc` direct compilation only.
