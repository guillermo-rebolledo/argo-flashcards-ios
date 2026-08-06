import Foundation

@testable import Flashcards

/// A `CardRepository` that hands out a fixed Deck of Cards and fails to write a Grade.
///
/// Separate from the other failing fakes rather than a flag on one of them, for the reason
/// [WriteFailingCardRepository] gives: it exists for one branch, and that branch — a Session that
/// composed fine and then could not record what the user just told it — is reachable only from a
/// repository that reads Cards and refuses that one write.
struct GradeFailingCardRepository: CardRepository {
  struct Failure: Error {}

  let cards: [CardSummary]

  func cards(inDeckWithID deckID: UUID) throws -> [CardSummary] { cards }

  @discardableResult
  func addCard(toDeckWithID deckID: UUID, front: String, back: String) throws -> CardSummary? {
    throw Failure()
  }

  func updateCard(withID id: UUID, front: String, back: String) throws { throw Failure() }

  func delete(cardWithID id: UUID) throws { throw Failure() }

  func recordGrade(_ grade: Grade, forCardWithID id: UUID) throws { throw Failure() }
}
