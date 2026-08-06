import Foundation
import SwiftData
import Testing

@testable import Flashcards

/// Driven against the real schema in an in-memory container, like the Deck repository's suite.
/// Every assertion is on what a subsequent read returns, so none of these tests knows how a write
/// is performed.
@Suite("Card repository")
struct CardRepositoryTests {

  /// A Deck repository and a Card repository over one store, sharing one clock — the two are
  /// always used together, and a Card cannot exist without a Deck to put it in.
  private func makeRepositories(
    now: Date = .at(2026, 3, 1, 9, 30)
  ) throws -> (SwiftDataDeckRepository, SwiftDataCardRepository, FixedDateProvider) {
    let container = try ModelContainer.makeInMemoryContainer()
    let context = ModelContext(container)
    let dateProvider = FixedDateProvider(now: now)
    return (
      SwiftDataDeckRepository(context: context, dateProvider: dateProvider),
      SwiftDataCardRepository(context: context, dateProvider: dateProvider),
      dateProvider
    )
  }

  @Test("A new Deck has no Cards")
  func aNewDeckHasNoCards() throws {
    let (decks, cards, _) = try makeRepositories()
    let deck = try decks.createDeck(named: "Spanish verbs")

    #expect(try cards.cards(inDeckWithID: deck.id).isEmpty)
  }

  @Test("An added Card is returned by the next read, with the Front and Back it was given")
  func addedCardIsRead() throws {
    let (decks, cards, _) = try makeRepositories()
    let deck = try decks.createDeck(named: "Spanish verbs")

    try cards.addCard(toDeckWithID: deck.id, front: "hablar", back: "to speak")

    let stored = try cards.cards(inDeckWithID: deck.id)
    #expect(stored.count == 1)
    #expect(stored.first?.front == "hablar")
    #expect(stored.first?.back == "to speak")
  }

  @Test("A new Card starts at a Mastery streak of zero, unseen, stamped with the current instant")
  func addedCardStartsUnstudied() throws {
    let (decks, cards, _) = try makeRepositories(now: .at(2026, 3, 1, 9, 30))
    let deck = try decks.createDeck(named: "Spanish verbs")

    let card = try #require(
      try cards.addCard(toDeckWithID: deck.id, front: "hablar", back: "to speak"))

    #expect(card.masteryStreak == 0)
    #expect(card.lastSeenAt == nil)
    #expect(card.createdAt == .at(2026, 3, 1, 9, 30))
    #expect(card.isMastered == false)
  }

  @Test("Cards are listed newest first, so a Card just added is at the top")
  func cardsAreListedNewestFirst() throws {
    let (decks, cards, dateProvider) = try makeRepositories()
    let deck = try decks.createDeck(named: "Spanish verbs")

    try cards.addCard(toDeckWithID: deck.id, front: "hablar", back: "to speak")
    dateProvider.advance(by: 60)
    try cards.addCard(toDeckWithID: deck.id, front: "comer", back: "to eat")

    #expect(try cards.cards(inDeckWithID: deck.id).map(\.front) == ["comer", "hablar"])
  }

  @Test("A Deck's Cards are its own — a read never returns another Deck's Cards")
  func cardsBelongToOneDeck() throws {
    let (decks, cards, dateProvider) = try makeRepositories()
    let spanish = try decks.createDeck(named: "Spanish verbs")
    dateProvider.advance(by: 60)
    let kanji = try decks.createDeck(named: "Kanji")

    try cards.addCard(toDeckWithID: spanish.id, front: "hablar", back: "to speak")
    try cards.addCard(toDeckWithID: kanji.id, front: "水", back: "water")

    #expect(try cards.cards(inDeckWithID: spanish.id).map(\.front) == ["hablar"])
    #expect(try cards.cards(inDeckWithID: kanji.id).map(\.front) == ["水"])
  }

  @Test("Adding a Card to a Deck that is not there stores nothing")
  func addingToAMissingDeckStoresNothing() throws {
    let (_, cards, _) = try makeRepositories()

    let card = try cards.addCard(toDeckWithID: UUID(), front: "hablar", back: "to speak")

    #expect(card == nil)
  }

  @Test("An edited Card reads back with its new Front and Back, keeping its identity")
  func updateIsRead() throws {
    let (decks, cards, _) = try makeRepositories()
    let deck = try decks.createDeck(named: "Spanish verbs")
    let card = try #require(
      try cards.addCard(toDeckWithID: deck.id, front: "hablar", back: "to speek"))

    try cards.updateCard(withID: card.id, front: "hablar", back: "to speak")

    let edited = try #require(try cards.cards(inDeckWithID: deck.id).first)
    #expect(edited.front == "hablar")
    #expect(edited.back == "to speak")
    #expect(edited.id == card.id)
    #expect(edited.createdAt == card.createdAt)
  }

  /// The rule ADR 0003 exists to protect, at the layer that could break it: the write that
  /// changes a Front and a Back has no business touching how well the Card is known.
  @Test("Editing a Card leaves its Mastery streak and last-seen timestamp untouched")
  func updateLeavesMasteryAlone() throws {
    let container = try ModelContainer.makeInMemoryContainer()
    let context = ModelContext(container)
    let dateProvider = FixedDateProvider(now: .at(2026, 3, 1))
    let decks = SwiftDataDeckRepository(context: context, dateProvider: dateProvider)
    let cards = SwiftDataCardRepository(context: context, dateProvider: dateProvider)
    let deck = try decks.createDeck(named: "Spanish verbs")
    let card = try #require(
      try cards.addCard(toDeckWithID: deck.id, front: "hablar", back: "to speek"))
    try studied(cardWithID: card.id, streak: 3, at: .at(2026, 3, 5), in: context)

    try cards.updateCard(withID: card.id, front: "hablar", back: "to speak")

    let edited = try #require(try cards.cards(inDeckWithID: deck.id).first)
    #expect(edited.masteryStreak == 3)
    #expect(edited.lastSeenAt == .at(2026, 3, 5))
    #expect(edited.isMastered)
  }

  @Test("A deleted Card is gone from the next read, and the others are left alone")
  func deleteIsRead() throws {
    let (decks, cards, dateProvider) = try makeRepositories()
    let deck = try decks.createDeck(named: "Spanish verbs")
    let card = try #require(
      try cards.addCard(toDeckWithID: deck.id, front: "hablar", back: "to speak"))
    dateProvider.advance(by: 60)
    try cards.addCard(toDeckWithID: deck.id, front: "comer", back: "to eat")

    try cards.delete(cardWithID: card.id)

    #expect(try cards.cards(inDeckWithID: deck.id).map(\.front) == ["comer"])
  }

  @Test("Editing or deleting a Card that is not there changes nothing")
  func operationsOnAMissingCardAreNoOps() throws {
    let (decks, cards, _) = try makeRepositories()
    let deck = try decks.createDeck(named: "Spanish verbs")
    try cards.addCard(toDeckWithID: deck.id, front: "hablar", back: "to speak")

    try cards.updateCard(withID: UUID(), front: "comer", back: "to eat")
    try cards.delete(cardWithID: UUID())

    #expect(try cards.cards(inDeckWithID: deck.id).map(\.front) == ["hablar"])
  }

  @Test("Deleting a Deck deletes its Cards, and leaves another Deck's Cards alone")
  func deletingADeckCascadesToItsCards() throws {
    let (decks, cards, dateProvider) = try makeRepositories()
    let spanish = try decks.createDeck(named: "Spanish verbs")
    dateProvider.advance(by: 60)
    let kanji = try decks.createDeck(named: "Kanji")
    try cards.addCard(toDeckWithID: spanish.id, front: "hablar", back: "to speak")
    try cards.addCard(toDeckWithID: spanish.id, front: "comer", back: "to eat")
    try cards.addCard(toDeckWithID: kanji.id, front: "水", back: "water")

    try decks.delete(deckWithID: spanish.id)

    #expect(try cards.cards(inDeckWithID: spanish.id).isEmpty)
    #expect(try cards.cards(inDeckWithID: kanji.id).map(\.front) == ["水"])
  }

  @Test("Cards written by one repository are read by the next one over the same store")
  func cardsSurviveANewRepositoryOverTheSameStore() throws {
    let container = try ModelContainer.makeInMemoryContainer()
    let dateProvider = FixedDateProvider(now: .at(2026, 3, 1))
    let decks = SwiftDataDeckRepository(
      context: ModelContext(container), dateProvider: dateProvider)
    let deck = try decks.createDeck(named: "Spanish verbs")
    let writer = SwiftDataCardRepository(
      context: ModelContext(container), dateProvider: dateProvider)
    try writer.addCard(toDeckWithID: deck.id, front: "hablar", back: "to speak")

    let reader = SwiftDataCardRepository(
      context: ModelContext(container), dateProvider: dateProvider)
    #expect(try reader.cards(inDeckWithID: deck.id).map(\.front) == ["hablar"])
  }

  @Test("A Deck reads back by its id, and a Deck that is not there reads back as nothing")
  func deckIsReadByID() throws {
    let (decks, _, _) = try makeRepositories()
    let deck = try decks.createDeck(named: "Spanish verbs")

    #expect(try decks.deck(withID: deck.id)?.name == "Spanish verbs")
    #expect(try decks.deck(withID: UUID()) == nil)
  }

  /// Grading is MEM-104's work; until it exists, a studied Card is made by writing the streak
  /// directly. The test above needs a Card with mastery on it, not a Session that produced one.
  private func studied(
    cardWithID id: UUID, streak: Int, at lastSeenAt: Date, in context: ModelContext
  ) throws {
    let card = try #require(try context.fetch(FetchDescriptor<Card>()).first { $0.id == id })
    card.masteryStreak = streak
    card.lastSeenAt = lastSeenAt
    try context.save()
  }
}
