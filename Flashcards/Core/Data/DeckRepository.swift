import Foundation
import SwiftData

/// What the app knows about a Deck when it is listing them.
///
/// A value type rather than the `@Model` itself, so a screen model hands the view something that
/// cannot be mutated behind its back and that a test can compare with `==`. The Deck's Cards are
/// deliberately absent: nothing that lists Decks needs them, and fetching them to show a row would
/// load the whole store to draw one screen.
struct DeckSummary: Identifiable, Hashable, Sendable {
  let id: UUID
  let name: String
  let createdAt: Date
}

/// Reading and writing Decks.
///
/// The protocol exists because the spec's architecture is repository protocols with SwiftData
/// implementations, and because it is the seam the screen's error path is exercised through. It is
/// **not** here so tests can swap the store out: behavioural tests run against
/// `SwiftDataDeckRepository` over an in-memory container, on the real schema, which is what makes
/// them catch schema and fetch bugs. See ADR 0007.
///
/// `@MainActor` because the whole app is — the project compiles with `MainActor` as the default
/// isolation, and a `ModelContext` is not `Sendable`. Nothing here does enough work to want its
/// own actor; when something does, it will be the thing that moves off, not this protocol.
@MainActor
protocol DeckRepository {
  /// Every Deck, newest first.
  func decks() throws -> [DeckSummary]

  /// Creates a Deck with the given name, stamped with the current instant.
  ///
  /// Names are not unique and are not checked for uniqueness: two Decks called "Chapter 3" are two
  /// Decks, and refusing the second would be inventing a rule the product does not have.
  @discardableResult
  func createDeck(named name: String) throws -> DeckSummary

  /// Renames the Deck with this id. A Deck that is no longer there is not an error — it is a
  /// screen acting on a list a moment out of date, and the outcome the caller wanted (no Deck by
  /// that name) already holds.
  func rename(deckWithID id: UUID, to name: String) throws

  /// Deletes the Deck with this id and, by the model's cascade rule, its Cards. Deleting a Deck
  /// that is no longer there is likewise not an error.
  func delete(deckWithID id: UUID) throws
}

/// The one implementation: SwiftData, over the app's real schema.
@MainActor
final class SwiftDataDeckRepository: DeckRepository {
  private let context: ModelContext
  private let dateProvider: any DateProvider

  init(context: ModelContext, dateProvider: any DateProvider) {
    self.context = context
    self.dateProvider = dateProvider
  }

  func decks() throws -> [DeckSummary] {
    let descriptor = FetchDescriptor<Deck>(
      sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
    return try context.fetch(descriptor).map(DeckSummary.init)
  }

  @discardableResult
  func createDeck(named name: String) throws -> DeckSummary {
    let deck = Deck(name: name, createdAt: dateProvider.now)
    context.insert(deck)
    try context.save()
    return DeckSummary(deck)
  }

  func rename(deckWithID id: UUID, to name: String) throws {
    guard let deck = try deck(withID: id) else { return }
    deck.name = name
    try context.save()
  }

  func delete(deckWithID id: UUID) throws {
    guard let deck = try deck(withID: id) else { return }
    context.delete(deck)
    try context.save()
  }

  private func deck(withID id: UUID) throws -> Deck? {
    var descriptor = FetchDescriptor<Deck>(predicate: #Predicate { $0.id == id })
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
  }
}

extension DeckSummary {
  fileprivate init(_ deck: Deck) {
    self.init(id: deck.id, name: deck.name, createdAt: deck.createdAt)
  }
}
