import Foundation
import SwiftData

/// What the app knows about a Card when it is listing one.
///
/// A value type rather than the `@Model` itself, for the reason [DeckSummary] gives: a screen
/// model hands the view something that cannot be mutated behind its back and that a test can
/// compare with `==`. Unlike a Deck's Cards, a Card's Mastery streak *is* carried — the Deck
/// detail screen filters and counts by it, and it is one integer per row.
///
/// `isMastered` is derived here from the same rule the model uses, so the list, the filter, and
/// the summary cannot disagree about what Mastered means. See ADR 0003.
struct CardSummary: Identifiable, Hashable, Sendable {
  let id: UUID
  let front: String
  let back: String
  let masteryStreak: Int
  let lastSeenAt: Date?
  let createdAt: Date

  var isMastered: Bool { masteryStreak >= Card.masteryThreshold }
}

/// Reading and writing the Cards in a Deck.
///
/// Separate from [DeckRepository] rather than folded into it, because the two are asked for by
/// different screens: the Deck list needs Decks without their Cards, and Deck detail needs one
/// Deck's Cards. A single protocol would hand every caller both.
///
/// `@MainActor` for the reason [DeckRepository] gives.
@MainActor
protocol CardRepository {
  /// The Cards in this Deck, newest first — the same order the Deck list uses, so a Card just
  /// added is at the top rather than below however many are already there.
  ///
  /// A Deck that is no longer there has no Cards, which is what this returns rather than an
  /// error: the caller is a screen acting on a list a moment out of date.
  func cards(inDeckWithID deckID: UUID) throws -> [CardSummary]

  /// Adds a Card to this Deck, stamped with the current instant, Learning and unseen.
  ///
  /// Returns `nil` if the Deck is no longer there — nothing is stored, because a Card outside a
  /// Deck has no meaning.
  @discardableResult
  func addCard(toDeckWithID deckID: UUID, front: String, back: String) throws -> CardSummary?

  /// Rewrites a Card's Front and Back, **and nothing else**.
  ///
  /// The Mastery streak and the last-seen timestamp are deliberately out of reach here: fixing a
  /// typo must not cost a learner their progress, and the surest way to guarantee that is for the
  /// write that changes the content to have no access to the rest. See ADR 0003.
  ///
  /// A Card that is no longer there is not an error, for the reason `cards(inDeckWithID:)` gives.
  func updateCard(withID id: UUID, front: String, back: String) throws

  /// Deletes this Card. Deleting one that is no longer there is likewise not an error.
  func delete(cardWithID id: UUID) throws
}

/// The one implementation: SwiftData, over the app's real schema.
@MainActor
final class SwiftDataCardRepository: CardRepository {
  private let context: ModelContext
  private let dateProvider: any DateProvider

  init(context: ModelContext, dateProvider: any DateProvider) {
    self.context = context
    self.dateProvider = dateProvider
  }

  func cards(inDeckWithID deckID: UUID) throws -> [CardSummary] {
    let descriptor = FetchDescriptor<Card>(
      predicate: #Predicate { $0.deck?.id == deckID },
      sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
    return try context.fetch(descriptor).map(CardSummary.init)
  }

  @discardableResult
  func addCard(toDeckWithID deckID: UUID, front: String, back: String) throws -> CardSummary? {
    guard let deck = try storedDeck(withID: deckID) else { return nil }

    let card = Card(front: front, back: back, createdAt: dateProvider.now)
    deck.cards.append(card)
    try context.save()
    return CardSummary(card)
  }

  func updateCard(withID id: UUID, front: String, back: String) throws {
    guard let card = try storedCard(withID: id) else { return }
    card.front = front
    card.back = back
    try context.save()
  }

  func delete(cardWithID id: UUID) throws {
    guard let card = try storedCard(withID: id) else { return }
    context.delete(card)
    try context.save()
  }

  private func storedDeck(withID id: UUID) throws -> Deck? {
    var descriptor = FetchDescriptor<Deck>(predicate: #Predicate { $0.id == id })
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
  }

  private func storedCard(withID id: UUID) throws -> Card? {
    var descriptor = FetchDescriptor<Card>(predicate: #Predicate { $0.id == id })
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
  }
}

extension CardSummary {
  fileprivate init(_ card: Card) {
    self.init(
      id: card.id,
      front: card.front,
      back: card.back,
      masteryStreak: card.masteryStreak,
      lastSeenAt: card.lastSeenAt,
      createdAt: card.createdAt)
  }
}
