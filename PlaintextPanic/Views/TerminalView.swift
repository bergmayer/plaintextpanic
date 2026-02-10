import SwiftUI

struct TerminalView: View {
    @EnvironmentObject var gameEngine: GameEngine

    private let phosphorGreen = Color(red: 0.2, green: 1.0, blue: 0.2)
    private let phosphorAmber = Color(red: 1.0, green: 0.75, blue: 0.0)
    private let phosphorWhite = Color(red: 0.95, green: 0.95, blue: 0.95)
    private let debugRed = Color(red: 1.0, green: 0.2, blue: 0.2)
    private let rows = 24
    private let padding: CGFloat = 20

    private var textColor: Color {
        if gameEngine.isDebugMode {
            return debugRed
        }
        switch gameEngine.letterColor {
        case .green: return phosphorGreen
        case .amber: return phosphorAmber
        case .white: return phosphorWhite
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height - (padding * 2)
            let lineHeight = availableHeight / CGFloat(rows)
            let fontSize = lineHeight * 0.85  // Font size slightly smaller than line height

            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<rows, id: \.self) { row in
                    Text(String(gameEngine.buffer[row]))
                        .font(.custom("PrintChar21", size: fontSize))
                        .foregroundColor(textColor)
                        .frame(height: lineHeight)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
    }
}

struct TerminalView_Previews: PreviewProvider {
    static var previews: some View {
        TerminalView()
            .environmentObject(GameEngine())
    }
}
