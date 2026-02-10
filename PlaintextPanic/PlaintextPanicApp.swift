import SwiftUI
import AppKit

// MARK: - Key Codes

private enum KeyCode {
    static let escape: UInt16   = 53
    static let tab: UInt16      = 48
    static let upArrow: UInt16  = 126
    static let downArrow: UInt16 = 125
    static let leftArrow: UInt16 = 123
    static let rightArrow: UInt16 = 124
}

@main
struct PlaintextPanicApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var gameEngine = GameEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameEngine)
                .background(WindowConfigurator())
                .onAppear {
                    appDelegate.gameEngine = gameEngine
                    appDelegate.setupKeyboardMonitor()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Replace the default About menu item with our custom About window
            CommandGroup(replacing: .appInfo) {
                Button("About Plaintext Panic") {
                    appDelegate.showAbout()
                }
                Divider()
                Button("Reset High Scores...") {
                    appDelegate.confirmResetHighScores()
                }
            }

            // Remove "New Window" - there can be only one
            CommandGroup(replacing: .newItem) { }

            // Add items to the View menu (replacing default toolbar commands)
            CommandGroup(replacing: .toolbar) {
                Button("High Scores") {
                    appDelegate.showHighScores()
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
            }

            // Replace the default Help menu with our custom How to Play window
            CommandGroup(replacing: .help) {
                Button("How to Play") {
                    appDelegate.showHelp()
                }
                .keyboardShortcut("?")
            }
        }

        Settings {
            SettingsView()
                .environmentObject(gameEngine)
        }
    }
}

// Configure the window to support resizing with aspect ratio and full screen
struct WindowConfigurator: NSViewRepresentable {
    // Default size and aspect ratio (1280x800 = 16:10 for App Store screenshots)
    static let defaultWidth: CGFloat = 1280
    static let defaultHeight: CGFloat = 800
    static let aspectRatio = defaultWidth / defaultHeight

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.isOpaque = false
                window.backgroundColor = .clear
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
                window.isMovableByWindowBackground = true

                // TRADEOFF: Window shadow vs edge resize handles
                // =============================================
                // With hasShadow = false, macOS only provides resize cursors at:
                // - All four corners (diagonal resize)
                // - Bottom edge (vertical resize)
                // Left and right edge resize handles require the shadow/border area.
                // Enabling hasShadow = true would add visible transparency artifacts
                // around the window edges, which looks bad with our custom beige frame.
                // Since aspectRatio is locked, corner/bottom resizing is functionally
                // equivalent to having all edges - the window scales proportionally.
                window.hasShadow = false

                window.collectionBehavior = [.fullScreenPrimary]

                // Disable window tabbing
                window.tabbingMode = .disallowed

                // Enable state restoration so user's window size is remembered
                window.isRestorable = true

                // Hide standard window buttons
                window.standardWindowButton(.closeButton)?.isHidden = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true

                // Set aspect ratio constraint
                window.aspectRatio = NSSize(width: WindowConfigurator.aspectRatio, height: 1.0)

                // Set minimum size
                window.minSize = NSSize(width: 550, height: 400)

                // Make the window content view layer-backed for proper transparency
                window.contentView?.wantsLayer = true
                window.contentView?.layer?.backgroundColor = .clear

                // Set initial window size on first launch only
                // Subsequent launches will restore user's preferred size via state restoration
                let hasLaunchedKey = "HasLaunchedBefore"
                if !UserDefaults.standard.bool(forKey: hasLaunchedKey) {
                    UserDefaults.standard.set(true, forKey: hasLaunchedKey)
                    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
                    let windowWidth = WindowConfigurator.defaultWidth
                    let windowHeight = WindowConfigurator.defaultHeight
                    let windowX = screenFrame.origin.x + (screenFrame.width - windowWidth) / 2
                    let windowY = screenFrame.origin.y + (screenFrame.height - windowHeight) / 2
                    let initialFrame = NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight)
                    window.setFrame(initialFrame, display: true)
                }

                // WORKAROUND: Title bar line artifact fix
                //
                // When combining these window settings:
                //   - .titled style (needed for resize/minimize/fullscreen support)
                //   - titlebarAppearsTransparent = true
                //   - titleVisibility = .hidden
                //   - hidden standard window buttons
                //   - .fullSizeContentView
                //
                // macOS renders a faint horizontal line where the title bar separator
                // would normally appear. This line disappears after any window resize.
                //
                // The issue appears to be a timing/compositing bug in AppKit: the initial
                // window render draws the separator line before the transparency settings
                // fully take effect. A resize forces a complete window frame recalculation
                // and layer recomposite, which correctly applies all transparency settings.
                //
                // This workaround resizes the window by 1 pixel and immediately back,
                // which is imperceptible to the user but triggers the necessary redraw.
                //
                // Tested on: macOS 15 (Sequoia)
                // Future macOS versions may fix this, making this workaround unnecessary.
                // To test: comment out the lines below and check if a faint line appears
                // at the top of the window on launch (but disappears after manual resize).
                let currentFrame = window.frame
                window.setFrame(NSRect(x: currentFrame.origin.x, y: currentFrame.origin.y,
                                       width: currentFrame.width + 1, height: currentFrame.height + 1), display: true)
                window.setFrame(currentFrame, display: true)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var gameEngine: GameEngine?
    private var eventMonitor: Any?

    // Window controllers for secondary windows
    private let aboutController = AboutWindowController()
    private let helpController = HelpWindowController()
    private let highScoresController = HighScoresWindowController()

    func showAbout() {
        aboutController.show()
    }

    func showHelp() {
        helpController.show()
    }

    func showHighScores() {
        guard let engine = gameEngine else { return }
        highScoresController.show(highScores: engine.highScores)
    }

    func setupKeyboardMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self, let engine = self.gameEngine else { return event }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // ESC - Context dependent
            if event.keyCode == KeyCode.escape {
                // First try to close definitions window if open
                if engine.closeDefinitionsWindow() {
                    return nil
                }
                engine.handleEscape()
                return nil
            }

            // Arrow keys - scroll word lists (up/down) and bingos (left/right)
            if event.keyCode == KeyCode.upArrow {
                engine.handleArrowKey(isUp: true)
                return nil
            }
            if event.keyCode == KeyCode.downArrow {
                engine.handleArrowKey(isUp: false)
                return nil
            }
            if event.keyCode == KeyCode.leftArrow {
                engine.handleHorizontalArrowKey(isLeft: true)
                return nil
            }
            if event.keyCode == KeyCode.rightArrow {
                engine.handleHorizontalArrowKey(isLeft: false)
                return nil
            }

            #if DEBUG
            // Debug shortcuts (Ctrl+Cmd+Opt)
            if modifiers.contains(.command) && modifiers.contains(.control) && modifiers.contains(.option) {
                if event.charactersIgnoringModifiers?.uppercased() == "D" {
                    engine.toggleDebugMode()
                    return nil
                }
                if event.charactersIgnoringModifiers?.uppercased() == "W" {
                    engine.debugSimulatePerfectRound()
                    return nil
                }
                if event.charactersIgnoringModifiers?.uppercased() == "B" {
                    engine.debugSimulateBingo()
                    return nil
                }
                if event.charactersIgnoringModifiers == "7" {
                    engine.debugStartMultiBingoRound()
                    return nil
                }
                if event.charactersIgnoringModifiers?.uppercased() == "X" {
                    engine.debugStartStressTest()
                    return nil
                }
                if event.charactersIgnoringModifiers?.uppercased() == "T" {
                    engine.debugSetShortTimer()
                    return nil
                }
            }
            #endif

            // TAB - Bingo hint
            if event.keyCode == KeyCode.tab {
                engine.handleHint()
                return nil
            }

            // Regular keys (no command modifier)
            if !modifiers.contains(.command) {
                if let chars = event.characters {
                    engine.handleKeyPress(chars)
                }
                return nil
            }

            return event
        }
    }

    func confirmResetHighScores() {
        let alert = NSAlert()
        alert.messageText = "Reset High Scores?"
        alert.informativeText = "This will permanently delete all high scores. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            gameEngine?.resetHighScores()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
