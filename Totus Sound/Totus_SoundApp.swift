//
//  Totus_SoundApp.swift
//  Totus Sound
//
//  Created by Julian Muehlschlegel on 8/2/26.
//

import SwiftUI

@main
struct Totus_SoundApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            TheaterFileCommands()
        }
    }
}

private struct TheaterFileCommands: Commands {
    @FocusedValue(\.theaterFileCommands) private var fileCommands

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Theater Setup") {
                fileCommands?.newSetup()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(fileCommands == nil)

            Button("Import Setup...") {
                fileCommands?.importSetup()
            }
            .keyboardShortcut("o", modifiers: [.command])
            .disabled(fileCommands == nil)

            Divider()

            Button("Export Setup...") {
                fileCommands?.exportSetup()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(fileCommands == nil)

            Button("Export Cue List...") {
                fileCommands?.exportCueList()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(fileCommands == nil)
        }
    }
}
