import SwiftUI

/// The app's shell: three tabs, each owning its own `NavigationStack`.
///
/// Settings keeps a tab rather than being demoted behind a gear, because a failed Generation
/// routes the user there — a destination reached from an error path should be one tap away.
///
/// **No custom tint and no brand colour is applied anywhere in this file, and none should be.**
/// System defaults throughout, per Apple's guidance that glass surfaces stay neutral and let
/// content show through. See ADR 0008.
/// Takes no dependencies: the shell itself needs none, and each screen will receive what it needs
/// through its own initialiser when it gains a model. Threading an unused `AppDependencies` through
/// here would be a parameter that exists to look like architecture.
struct RootView: View {
  var body: some View {
    TabView {
      Tab("Decks", systemImage: "rectangle.on.rectangle") {
        NavigationStack {
          DecksScreen()
        }
      }

      Tab("Progress", systemImage: "chart.bar") {
        NavigationStack {
          ProgressScreen()
        }
      }

      Tab("Settings", systemImage: "gearshape") {
        NavigationStack {
          SettingsScreen()
        }
      }
    }
    // The tab bar minimizes as the user scrolls down, so list content reads as content passing
    // *under* glass rather than sitting in a box above it. This is the behaviour the whole
    // control-layer/content-layer split depends on being visible — see ADR 0006.
    .tabBarMinimizeBehavior(.onScrollDown)
  }
}

/// Previews are the verification surface for the two things this shell must get right and that no
/// unit test can assert: that type scales, and that light and dark both come from the system.
///
/// Nothing here sets a `colorScheme` override or a fixed font. Light and dark follow the system
/// because nothing forces them; the previews below exist so a regression is visible.
#Preview("Light") {
  RootView()
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  RootView()
    .preferredColorScheme(.dark)
}

#Preview("Accessibility XXXL") {
  RootView()
    .dynamicTypeSize(.accessibility5)
}
