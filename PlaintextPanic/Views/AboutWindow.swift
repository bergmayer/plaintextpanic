import SwiftUI
import AppKit

// MARK: - About Content Row Views

struct AboutHeaderRow: View {
    let rowIndex: Int
    let lineHeight: CGFloat = 22
    let inkColor = Color(red: 0.17, green: 0.17, blue: 0.17)

    var body: some View {
        ZStack {
            GreenBarRow(index: rowIndex, height: lineHeight)
            Text("PLAINTEXT PANIC")
                .font(.custom("Courier", size: 16).bold())
                .foregroundColor(inkColor)
        }
    }
}

struct AboutTextRow: View {
    let text: String
    let rowIndex: Int
    let isBold: Bool
    let url: URL?
    let lineHeight: CGFloat = 22
    let inkColor = Color(red: 0.17, green: 0.17, blue: 0.17)

    init(_ text: String, rowIndex: Int, isBold: Bool = false, link url: URL? = nil) {
        self.text = text
        self.rowIndex = rowIndex
        self.isBold = isBold
        self.url = url
    }

    var body: some View {
        ZStack {
            GreenBarRow(index: rowIndex, height: lineHeight)
            if let url = url {
                Link(text, destination: url)
                    .font(.custom("Courier", size: 12))
                    .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.6))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(text)
                    .font(isBold ? .custom("Courier", size: 13).bold() : .custom("Courier", size: 12))
                    .foregroundColor(inkColor.opacity(isBold ? 1.0 : 0.85))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct AboutDottedRow: View {
    let rowIndex: Int
    let lineHeight: CGFloat = 22

    var body: some View {
        ZStack {
            GreenBarRow(index: rowIndex, height: lineHeight)
            DottedSeparator()
        }
    }
}

struct AboutWrappingTextRow: View {
    let text: String
    let startRowIndex: Int
    let rowCount: Int
    let lineHeight: CGFloat = 22
    let inkColor = Color(red: 0.17, green: 0.17, blue: 0.17)

    init(_ text: String, startRowIndex: Int, rowCount: Int) {
        self.text = text
        self.startRowIndex = startRowIndex
        self.rowCount = rowCount
    }

    var body: some View {
        ZStack {
            // Background spans multiple rows
            VStack(spacing: 0) {
                ForEach(0..<rowCount, id: \.self) { i in
                    GreenBarRow(index: startRowIndex + i, height: lineHeight)
                }
            }
            // Wrapping text centered in the area
            Text(text)
                .font(.custom("Courier", size: 11))
                .foregroundColor(inkColor.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 8)
        }
        .frame(height: CGFloat(rowCount) * lineHeight)
    }
}

struct AboutLogoRow: View {
    let rowIndex: Int
    let rowSpan: Int
    let lineHeight: CGFloat = 22
    let naspaURL = URL(string: "https://www.scrabbleplayers.org")!

    var body: some View {
        ZStack {
            // Background spans multiple rows
            VStack(spacing: 0) {
                ForEach(0..<rowSpan, id: \.self) { i in
                    GreenBarRow(index: rowIndex + i, height: lineHeight)
                }
            }
            // Logo as clickable link
            Link(destination: naspaURL) {
                if let nsImage = NSImage(named: "NASPA_logo_small") {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: CGFloat(rowSpan) * lineHeight - 8)
                } else {
                    Text("[NASPA Logo]")
                        .font(.custom("Courier", size: 12))
                        .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.6))
                }
            }
        }
        .frame(height: CGFloat(rowSpan) * lineHeight)
    }
}

// MARK: - About Window View

struct AboutWindow: View {
    @Environment(\.dismiss) private var dismiss

    private let naspaURL = URL(string: "https://www.scrabbleplayers.org")!
    private let kreativeURL = URL(string: "https://www.kreativekorp.com/software/fonts/apple2/")!
    private let licenseURL = URL(string: "https://github.com/bergmayer/plaintextpanic/blob/main/LICENSE")!

    private var versionString: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return "VERSION \(version)"
        }
        return "VERSION 1.0"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Row 0: Header
            PaperRow(rowIndex: 0) {
                AboutHeaderRow(rowIndex: 0)
            }

            // Row 1: Version
            PaperRow(rowIndex: 1) {
                AboutTextRow(versionString, rowIndex: 1)
            }

            // Row 2: Dotted separator
            PaperRow(rowIndex: 2) {
                AboutDottedRow(rowIndex: 2)
            }

            // Row 3: App Copyright
            PaperRow(rowIndex: 3) {
                AboutTextRow("\u{00A9} 2025 John Bergmayer", rowIndex: 3, isBold: true)
            }

            // Row 4: GPL License
            PaperRow(rowIndex: 4) {
                AboutTextRow("GPL 3.0 License", rowIndex: 4)
            }

            // Row 5: Dotted separator
            PaperRow(rowIndex: 5) {
                AboutDottedRow(rowIndex: 5)
            }

            // Rows 6-9: NASPA Logo (4 rows tall)
            PaperRowMulti(startIndex: 6, count: 4) {
                AboutLogoRow(rowIndex: 6, rowSpan: 4)
            }

            // Row 10: Empty
            PaperRow(rowIndex: 10) {
                EmptyContentRow(rowIndex: 10)
            }

            // Row 11: NASPA Word List title (clickable)
            PaperRow(rowIndex: 11) {
                AboutTextRow("NASPA Word List 2023 Edition", rowIndex: 11, isBold: true, link: naspaURL)
            }

            // Row 12: NASPA Copyright
            PaperRow(rowIndex: 12) {
                AboutTextRow("\u{00A9} NASPA 2025", rowIndex: 12)
            }

            // Row 13: Empty
            PaperRow(rowIndex: 13) {
                EmptyContentRow(rowIndex: 13)
            }

            // Rows 14-17: License text (spans multiple rows with wrapping)
            PaperRowMulti(startIndex: 14, count: 4) {
                AboutWrappingTextRow(
                    "The copy included in this app is licensed for personal use. You may not use it for any commercial purposes.",
                    startRowIndex: 14,
                    rowCount: 4
                )
            }

            // Row 18: Dotted separator
            PaperRow(rowIndex: 18) {
                AboutDottedRow(rowIndex: 18)
            }

            // Row 19: Font credits
            PaperRow(rowIndex: 19) {
                AboutTextRow("Fonts by Kreative Korp", rowIndex: 19, link: kreativeURL)
            }

            // Row 20: Dotted separator
            PaperRow(rowIndex: 20) {
                AboutDottedRow(rowIndex: 20)
            }

            // Row 21: License link
            PaperRow(rowIndex: 21) {
                AboutTextRow("License", rowIndex: 21, link: licenseURL)
            }
        }
        .background(Color(red: 0.2, green: 0.2, blue: 0.2))
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        .background(
            Button("") { dismiss() }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
        )
        .frame(width: 340, height: 484)
    }
}

// MARK: - Window Controller
//
// Uses same crash prevention patterns as DefinitionsWindowController.
// See DefinitionsWindow.swift for detailed explanation.

class AboutWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var hostingController: NSHostingController<AboutWindow>?

    func show() {
        // Close existing window safely before creating new one
        if window != nil {
            performSafeClose()
        }

        let contentView = AboutWindow()
        let hosting = NSHostingController(rootView: contentView)
        hostingController = hosting

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 484),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        // CRASH PREVENTION: Disable all animations
        newWindow.animationBehavior = .none

        // CRASH PREVENTION: Don't auto-release window when closed
        newWindow.isReleasedWhenClosed = false

        newWindow.contentViewController = hosting
        newWindow.title = "About Plaintext Panic"
        newWindow.delegate = self
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)

        self.window = newWindow
    }

    func close() {
        performSafeClose()
    }

    private func performSafeClose() {
        guard let w = window else { return }

        w.delegate = nil
        w.contentViewController = nil
        w.animationBehavior = .none
        w.close()

        let windowToRelease = w
        let hostingToRelease = hostingController

        self.window = nil
        self.hostingController = nil

        DispatchQueue.main.async {
            _ = windowToRelease
            _ = hostingToRelease
        }
    }

    // NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === window else { return }

        closingWindow.contentViewController = nil

        let windowToRelease = window
        let hostingToRelease = hostingController

        window = nil
        hostingController = nil

        DispatchQueue.main.async {
            _ = windowToRelease
            _ = hostingToRelease
        }
    }
}
