// JSONViewerApp.swift
// SwiftUI App entry point. Main window + a separate result Window scene that
// renders the latest extraction payload from the shared AppModel.

import SwiftUI

@main
struct JSONViewerApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("JSON Viewer") {
            ContentView()
                .environmentObject(model)
        }
        .windowResizability(.contentMinSize)

        Window("Extraction Result", id: "result") {
            ResultView()
                .environmentObject(model)
        }
        .windowResizability(.contentMinSize)

        Window("JSON Compare", id: "compare") {
            CompareView()
                .environmentObject(model)
        }
        .windowResizability(.contentMinSize)
    }
}
