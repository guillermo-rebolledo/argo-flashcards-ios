import Foundation
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
          SettingsScreen(settings: dependencies.settings)
        }
      }
    }
    // The tab bar minimizes as the user scrolls down, so list content reads as content passing
    // *under* glass rather than sitting in a box above it. This is the behaviour the whole
    // control-layer/content-layer split depends on being visible — see ADR 0006.
    .tabBarMinimizeBehavior(.onScrollDown)
    // The theme override, applied at the top of the app so it reaches everything below including a
    // Session's cover. `nil` here is the whole app following the system, which is the default and
    // is what this file said before the setting existed. It is **not** a tint: see ADR 0008.
    .preferredColorScheme(dependencies.settings.theme.colorScheme)
    // Read once here and handed down, so Review does not have to know a settings object exists —
    // and so a change made while a Session is up reaches the Card that is already on screen.
    .environment(\.cardAnimations, dependencies.settings.cardAnimations)
  }
}

/// Previews are the verification surface for the two things this shell must get right and that no
/// unit test can assert: that type scales, and that light and dark both come from the system.
///
/// Nothing here sets a fixed font, and the shell's own `colorScheme` is whatever the theme setting
/// resolves to — `nil`, and so the system's, until a learner overrides it. The previews below exist
/// so a regression is visible.
///
/// Each builds the shell over an in-memory store and a defaults suite of its own, so a preview
/// never writes into the real store or the real settings, and two previews never see each other's
/// Decks.
@MainActor
private func previewDependencies() -> AppDependencies {
  AppDependencies(
    modelContainer: try! ModelContainer.makeInMemoryContainer(),
    settings: AppSettings(defaults: UserDefaults(suiteName: "preview.\(UUID())")!))
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
