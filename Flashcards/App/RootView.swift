import SwiftData
import SwiftUI

/// The app's shell: three tabs, each owning its own `NavigationStack`.
///
/// Settings keeps a tab rather than being demoted behind a gear, because a failed Generation
/// routes the user there — a destination reached from an error path should be one tap away.
///
/// **No custom tint and no brand colour is applied anywhere in this file, and none should be.**
/// System defaults throughout, per Apple's guidance that glass surfaces stay neutral and let
/// content show through. See ADR 0008.
/// The shell needs nothing itself, but it is where screen models are given a lifetime: a model
/// held in `@State` here survives tab switches, so the Decks list is not rebuilt and re-read every
/// time the user comes back to it. Progress and Settings gain theirs when they gain models.
struct RootView: View {
  @State private var decksModel: DecksModel

  /// Kept so the shell can build a screen model on demand — Deck detail's is built per push, not
  /// once here. It goes no further than this file: a screen is handed the one closure it needs,
  /// never this, so no screen can reach into the composition root for anything else in it.
  private let dependencies: AppDependencies

  init(dependencies: AppDependencies) {
    self.dependencies = dependencies
    _decksModel = State(initialValue: dependencies.makeDecksModel())
  }

  var body: some View {
    TabView {
      Tab("Decks", systemImage: "rectangle.on.rectangle") {
        NavigationStack {
          DecksScreen(
            model: decksModel,
            makeDeckDetailModel: { dependencies.makeDeckDetailModel(for: $0) },
            makeSessionModel: { dependencies.makeSessionModel(forDeckWithID: $0.id) })
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
///
/// Each builds the shell over an in-memory store, so a preview never writes into the real one and
/// two previews never see each other's Decks.
private func previewDependencies() -> AppDependencies {
  AppDependencies(modelContainer: try! ModelContainer.makeInMemoryContainer())
}

#Preview("Light") {
  RootView(dependencies: previewDependencies())
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  RootView(dependencies: previewDependencies())
    .preferredColorScheme(.dark)
}

#Preview("Accessibility XXXL") {
  RootView(dependencies: previewDependencies())
    .dynamicTypeSize(.accessibility5)
}
