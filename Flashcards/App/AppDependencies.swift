import Foundation
import SwiftData

/// The composition root.
///
/// Everything the app needs that it does not construct on the spot is assembled here, once, at
/// the entry point, and passed down through initialisers. There is **no DI container and no
/// singletons**: with two seams — `DateProvider` and, later, `CardGenerator` — a registration DSL
/// would solve a problem this design already avoids.
///
/// The rule this type exists to enforce: a screen model takes what it needs as initialiser
/// parameters. It does not reach for a shared instance, and it does not know this type exists.
struct AppDependencies {
  let modelContainer: ModelContainer
  let dateProvider: any DateProvider

  /// The one context the screens read and write through.
  ///
  /// One rather than one-per-screen, because two contexts over the same container are two copies
  /// of the object graph: a Deck renamed through one is stale in the other until it re-fetches,
  /// which is a bug the app would only see once two screens showed the same Deck. Tests make their
  /// own context per test, which is what keeps them isolated from each other.
  let mainContext: ModelContext

  init(modelContainer: ModelContainer, dateProvider: any DateProvider = SystemDateProvider()) {
    self.modelContainer = modelContainer
    self.dateProvider = dateProvider
    self.mainContext = ModelContext(modelContainer)
  }

  /// Builds the Decks screen's model. Assembly lives here rather than in the view so a screen
  /// never names a concrete repository — the one rule this type exists to enforce.
  func makeDecksModel() -> DecksModel {
    DecksModel(
      repository: SwiftDataDeckRepository(context: mainContext, dateProvider: dateProvider))
  }

  /// Assembles the production graph.
  static func makeLive() throws -> AppDependencies {
    AppDependencies(
      modelContainer: try ModelContainer.makeApplicationContainer(),
      dateProvider: SystemDateProvider()
    )
  }
}
