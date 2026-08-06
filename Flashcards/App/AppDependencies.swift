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

  init(modelContainer: ModelContainer, dateProvider: any DateProvider = SystemDateProvider()) {
    self.modelContainer = modelContainer
    self.dateProvider = dateProvider
  }

  /// Assembles the production graph.
  static func makeLive() throws -> AppDependencies {
    AppDependencies(
      modelContainer: try ModelContainer.makeApplicationContainer(),
      dateProvider: SystemDateProvider()
    )
  }
}
