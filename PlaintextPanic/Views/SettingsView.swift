import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var gameEngine: GameEngine

    var body: some View {
        Form {
            Section("Word List") {
                Picker("Word List", selection: Binding(
                    get: { gameEngine.currentWordList },
                    set: { gameEngine.switchWordList(to: $0) }
                )) {
                    Text("Full NASPA Word List").tag(WordListType.full)
                    Text("Common 7-Letter Words").tag(WordListType.common)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                .disabled(gameEngine.gameMode != .titleScreen)

                if gameEngine.gameMode != .titleScreen {
                    Text("Word list can only be changed from the title screen.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Display") {
                Picker("Letter Color", selection: Binding(
                    get: { gameEngine.letterColor },
                    set: { gameEngine.switchLetterColor(to: $0) }
                )) {
                    Text("Green").tag(LetterColor.green)
                    Text("Amber").tag(LetterColor.amber)
                    Text("White").tag(LetterColor.white)
                }
                .pickerStyle(.radioGroup)
            }

            Section("Sound") {
                Toggle("Sound Effects", isOn: Binding(
                    get: { gameEngine.isSoundEnabled },
                    set: { _ in gameEngine.toggleSound() }
                ))
            }
        }
        .formStyle(.grouped)
        .frame(width: 350)
        .fixedSize()
    }
}
