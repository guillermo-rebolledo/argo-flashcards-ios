import SwiftUI

/// The Settings tab.
///
/// Scaffold only. API key entry, Session length, Reminders, the theme override, and the animation
/// toggle arrive with their own tickets.
///
/// This is a tab rather than a gear in a toolbar because a failed Generation routes the user here
/// — a destination reached from an error path should be one tap away.
struct SettingsScreen: View {
  var body: some View {
    List {
    }
    .navigationTitle("Settings")
  }
}

#Preview {
  NavigationStack {
    SettingsScreen()
  }
}
