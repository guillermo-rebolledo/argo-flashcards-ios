import Foundation

@testable import Flashcards

/// A `CardRepository` whose every operation fails, for the same single purpose
/// [FailingDeckRepository] exists for: an in-memory container cannot be made to fail a read on
/// demand, and the branch where Deck detail reports a broken store rather than an empty Deck
/// would otherwise be unexercised.
struct FailingCardRepository: CardRepository {
  struct Failure: Error {}

  func cards(inDeckWithID deckID: UUID) throws -> [CardSummary] { throw Failure() }

  @discardableResult
  func addCard(toDeckWithID deckID: UUID, front: String, back: String) throws -> CardSummary? {
    throw Failure()
  }

  func updateCard(withID id: UUID, front: String, back: String) throws { throw Failure() }

  func delete(cardWithID id: UUID) throws { throw Failure() }
}

/// A `CardRepository` that reads an empty Deck happily and fails every write.
///
/// Separate from [FailingCardRepository] rather than a flag on it, because it exists for a
/// different branch: a screen that read its Deck fine and then could not write to it. Without a
/// fake that can be read but not written, that branch and the failed-read branch are
/// indistinguishable, and a test aiming at the write would pass on the read failing.
struct WriteFailingCardRepository: CardRepository {
  struct Failure: Error {}

  func cards(inDeckWithID deckID: UUID) throws -> [CardSummary] { [] }

  @discardableResult
  func addCard(toDeckWithID deckID: UUID, front: String, back: String) throws -> CardSummary? {
    throw Failure()
  }

  func updateCard(withID id: UUID, front: String, back: String) throws { throw Failure() }

  func delete(cardWithID id: UUID) throws { throw Failure() }
}
