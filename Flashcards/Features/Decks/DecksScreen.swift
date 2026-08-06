import SwiftUI

/// The home tab.
///
/// Scaffold only. The "Up next" card, the Deck list, the toolbar `+` menu, and the first-launch
/// empty state all arrive with their own tickets. What is settled here is the shell: a `List` on
/// the content layer, under a glass tab bar, with a large navigation title.
struct DecksScreen: View {
  var body: some View {
    List {
    }
    .navigationTitle("Decks")
  }
}

#Preview {
  NavigationStack {
    DecksScreen()
  }
}
