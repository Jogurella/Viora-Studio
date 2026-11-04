import SwiftUI
import CoreText

@main struct VioraStudioApp: App {
    init() {
        for name in ["SpaceGrotesk[wght]", "Manrope[wght]", "JetBrainsMono[wght]"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") { CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) }
        }
    }
    @State private var studio = StudioModel()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            StudioRoot(studio: studio)
                .preferredColorScheme(.dark)
                .tint(VioraTheme.violet)
                .task { await studio.restoreConnection() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await studio.reconnectIfNeeded() } }
                }
                #if os(macOS)
                .frame(minWidth: 940, minHeight: 680)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1400, height: 900)
        .commands {
            CommandGroup(after: .newItem) { Button("Generieren") { studio.enqueue() }.keyboardShortcut(.return, modifiers: .command).disabled(!studio.canGenerate) }
            CommandGroup(replacing: .appSettings) { Button("Einstellungen …") { studio.showSettings = true }.keyboardShortcut(",", modifiers: .command) }
        }
        #endif
    }
}
