import SwiftData
import SwiftUI

@main
struct FlashcardsApp: App {
  /// The composition root, assembled once here and passed down by initialiser.
  private let dependencies: AppDependencies

  init() {
    do {
      dependencies = try AppDependencies.makeLive()
    } catch {
      // The store failing to open is not a recoverable condition: there is no app without it, and
      // no meaningful screen to show instead. Crashing here surfaces the real error rather than
      // producing an app that silently persists nothing.
      fatalError("Could not open the Flashcards store: \(error)")
    }
  }

  var body: some Scene {
    WindowGroup {
      RootView()
    }
    // The container is deliberately **not** placed in the SwiftUI environment via
    // `.modelContainer(_:)`. Doing so is what makes `@Query` available in every view for free, and
    // the spec rules `@Query` out: the rules worth protecting — mastery, Session composition,
    // "Up next" selection — live in the layer `@Query` would dissolve into the view, and keeping
    // them out of it is what makes them testable without a simulator.
    //
    // It is held here instead and handed to screen models through their initialisers, which is the
    // only injection path this app has. See `AppDependencies`.
  }
}
