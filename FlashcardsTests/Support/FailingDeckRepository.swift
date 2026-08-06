import Foundation

@testable import Flashcards

/// A `DeckRepository` whose every operation fails.
///
/// The store itself is never faked — every behavioural test in this suite runs against the real
/// schema in an in-memory container, which is the choice the spec's Testing Decisions make. This
/// exists for the one thing that container cannot produce on demand: a read that fails. Without
/// it, the branch where the screen reports a broken store instead of posing as a first launch
/// would be the only unexercised path on the screen.
///
/// It records nothing and verifies nothing, in keeping with [FixedDateProvider].
struct FailingDeckRepository: DeckRepository {
  struct Failure: Error {}

  func decks() throws -> [DeckSummary] { throw Failure() }

  func deck(withID id: UUID) throws -> DeckSummary? { throw Failure() }

  @discardableResult
  func createDeck(named name: String) throws -> DeckSummary { throw Failure() }

  func rename(deckWithID id: UUID, to name: String) throws { throw Failure() }

  func delete(deckWithID id: UUID) throws { throw Failure() }
}
