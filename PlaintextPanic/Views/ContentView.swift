import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var gameEngine: GameEngine
    @State private var isFullScreen = false

    // Barrel distortion strength (0.0 = none, 0.05-0.1 = subtle, 0.15+ = strong)
    private let bulgeStrength: Float = 0.095

    // Apple II beige colors
    private let appleBeige = Color(red: 0.85, green: 0.82, blue: 0.72)
    private let appleBeigeLight = Color(red: 0.90, green: 0.87, blue: 0.78)
    private let appleBeigeDark = Color(red: 0.70, green: 0.67, blue: 0.58)

    // Base design size (16:10 aspect ratio for App Store screenshots)
    private let baseWidth: CGFloat = 1280
    private let baseHeight: CGFloat = 800

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / baseWidth, geometry.size.height / baseHeight)
            let scaledCornerRadius = 30 * scale

            ZStack {
                // In full screen, use black background for letterboxing
                if isFullScreen {
                    Color.black
                }

                // Beige monitor casing - fixed size in full screen
                RoundedRectangle(cornerRadius: scaledCornerRadius)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [appleBeigeLight, appleBeige, appleBeigeDark]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: baseWidth * scale, height: baseHeight * scale)

                // Screen area - scaled content
                TerminalView()
                    .frame(width: baseWidth - 80, height: baseHeight - 80)
                    .modifier(CRTEffect(bulgeStrength: bulgeStrength))
                    .scaleEffect(scale)

                // Window controls in the beige area (hide in full screen)
                if !isFullScreen {
                    VStack {
                        HStack {
                            WindowControlButtons()
                                .scaleEffect(scale)
                                .padding(.leading, 15 * scale)
                                .padding(.top, 12 * scale)
                            Spacer()
                        }
                        Spacer()
                    }
                    .frame(width: baseWidth * scale, height: baseHeight * scale)
                }

                // Banana "logo" on right beige border (like Apple logo on Apple II monitor)
                HStack {
                    Spacer()
                    VStack {
                        Spacer()
                        Text("🍌")
                            .font(.system(size: 28 * scale))
                        Spacer()
                            .frame(height: 50 * scale)
                    }
                    .frame(width: 40 * scale)
                }
                .frame(width: baseWidth * scale, height: baseHeight * scale)

                // DEBUG indicator in beige area (only in debug builds)
                #if DEBUG
                VStack {
                    Text("DEBUG")
                        .font(.custom("Courier", size: 14 * scale).bold())
                        .foregroundColor(Color(red: 0.5, green: 0.0, blue: 0.0))
                        .padding(.top, 8 * scale)
                    Spacer()
                }
                .frame(width: baseWidth * scale, height: baseHeight * scale)
                #endif
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(isFullScreen ? Color.black : Color.clear)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
            isFullScreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            isFullScreen = false
        }
    }
}

// Custom traffic light window controls
struct WindowControlButtons: View {
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            // Close button
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                ZStack {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.38, blue: 0.34))
                        .frame(width: 12, height: 12)
                    if isHovering {
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.black.opacity(0.5))
                    }
                }
            }
            .buttonStyle(.plain)

            // Minimize button
            Button(action: {
                NSApplication.shared.windows.first?.miniaturize(nil)
            }) {
                ZStack {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.79, blue: 0.28))
                        .frame(width: 12, height: 12)
                    if isHovering {
                        Image(systemName: "minus")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.black.opacity(0.5))
                    }
                }
            }
            .buttonStyle(.plain)

            // Full screen button
            Button(action: {
                NSApplication.shared.windows.first?.toggleFullScreen(nil)
            }) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.18, green: 0.8, blue: 0.25))
                        .frame(width: 12, height: 12)
                    if isHovering {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundColor(.black.opacity(0.5))
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct CRTEffect: ViewModifier {
    let bulgeStrength: Float

    func body(content: Content) -> some View {
        content
            .overlay(ScanlineOverlay())
            .shadow(color: Color(red: 0.2, green: 1.0, blue: 0.2).opacity(0.5), radius: 2)
            .shadow(color: Color(red: 0.2, green: 1.0, blue: 0.2).opacity(0.3), radius: 8)
            .drawingGroup() // Rasterize for shader
            .distortionEffect(
                ShaderLibrary.crtBulge(
                    .boundingRect,
                    .float(bulgeStrength)
                ),
                maxSampleOffset: CGSize(width: 100, height: 100)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(VignetteOverlay())
            .overlay(ScreenGlare())
    }
}

struct VignetteOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.5)
                ]),
                center: .center,
                startRadius: min(geometry.size.width, geometry.size.height) * 0.3,
                endRadius: max(geometry.size.width, geometry.size.height) * 0.6
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .allowsHitTesting(false)
    }
}

struct ScanlineOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ForEach(0..<Int(geometry.size.height / 2), id: \.self) { _ in
                    Rectangle()
                        .fill(Color.black.opacity(0.15))
                        .frame(height: 1)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 1)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct ScreenGlare: View {
    var body: some View {
        GeometryReader { geometry in
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.05),
                    Color.clear
                ]),
                center: .topLeading,
                startRadius: 0,
                endRadius: geometry.size.width * 0.8
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .allowsHitTesting(false)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(GameEngine())
    }
}
