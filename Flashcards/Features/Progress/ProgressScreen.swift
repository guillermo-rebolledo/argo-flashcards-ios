import SwiftUI

/// The Progress tab.
///
/// Scaffold only. The Day streak, the seven-day grid, the totals tiles, and the no-data empty
/// state arrive with their own tickets — all computed as folds over the Session log, in a single
/// type, per ADR 0007.
struct ProgressScreen: View {
  var body: some View {
    List {
    }
    .navigationTitle("Progress")
  }
}

#Preview {
  NavigationStack {
    ProgressScreen()
  }
}
