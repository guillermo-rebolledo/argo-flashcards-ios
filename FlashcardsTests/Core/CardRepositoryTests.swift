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
    let (decks, cards, dateProvider) = try makeRepositories(now: .at(2026, 3, 5))
    let deck = try decks.createDeck(named: "Spanish verbs")
    let card = try #require(
      try cards.addCard(toDeckWithID: deck.id, front: "hablar", back: "to speek"))
    for _ in 1...Card.masteryThreshold {
      try cards.recordGrade(.knewIt, forCardWithID: card.id)
    }
    dateProvider.advance(by: 60)

    try cards.updateCard(withID: card.id, front: "hablar", back: "to speak")

    let edited = try #require(try cards.cards(inDeckWithID: deck.id).first)
    #expect(edited.masteryStreak == Card.masteryThreshold)
    #expect(edited.lastSeenAt == .at(2026, 3, 5))
    #expect(edited.isMastered)
  }

  /// The mastery rule, **translated from the Android suite** (`LocalCardRepositoryTest.kt`) so
  /// both apps are pinned to the same numbers. Everything below reads the Card back rather than
  /// watching how the streak was written.
  @Test("`Knew it` lifts the Mastery streak by one, and `Again` drops it to zero")
  func gradesMoveTheMasteryStreak() throws {
    let (decks, cards, _) = try makeRepositories()
    let deck = try decks.createDeck(named: "Spanish verbs")
    let card = try #require(
      try cards.addCard(toDeckWithID: deck.id, front: "hablar", back: "to speak"))

    try cards.recordGrade(.knewIt, forCardWithID: card.id)
    #expect(try cards.cards(inDeckWithID: deck.id).first?.masteryStreak == 1)

    try cards.recordGrade(.knewIt, forCardWithID: card.id)
    #expect(try cards.cards(inDeckWithID: deck.id).first?.masteryStreak == 2)

    try cards.recordGrade(.again, forCardWithID: card.id)
    #expect(try cards.cards(inDeckWithID: deck.id).first?.masteryStreak == 0)
  }

  @Test("Three consecutive `Knew it` Grades make a Card Mastered, and two do not")
  func masteryTakesThreeConsecutiveKnewIts() throws {
    let (decks, cards, _) = try makeRepositories()
    let deck = try decks.createDeck(named: "Spanish verbs")
    let card = try #require(
      try cards.addCard(toDeckWithID: deck.id, front: "hablar", back: "to speak"))

    for _ in 1..<Card.masteryThreshold {
      try cards.recordGrade(.knewIt, forCardWithID: card.id)
    }
    #expect(try cards.cards(inDeckWithID: deck.id).first?.isMastered == false)

    try cards.recordGrade(.knewIt, forCardWithID: card.id)
    #expect(try cards.cards(inDeckWithID: deck.id).first?.isMastered == true)
  }

  /// One `Again` says the Card did not come back, whatever the run before it was — which is also
  /// what returns a Mastered Card to Learning.
  @Test("`Again` on a Mastered Card returns it to Learning with a streak of zero")
  func againDemotesAMasteredCard() throws {
    let (decks, cards, _) = try makeRepositories()
    let deck = try decks.createDeck(named: "Spanish verbs")
    let card = try #require(
      try cards.addCard(toDeckWithID: deck.id, front: "hablar", back: "to speak"))
    for _ in 1...Card.masteryThreshold {
      try cards.recordGrade(.knewIt, forCardWithID: card.id)
    }

    try cards.recordGrade(.again, forCardWithID: card.id)

    let graded = try #require(try cards.cards(inDeckWithID: deck.id).first)
    #expect(graded.masteryStreak == 0)
    #expect(!graded.isMastered)
  }

  @Test("Both Grades stamp the Card as seen at the moment it was Graded")
  func gradingStampsLastSeen() throws {
    let (decks, cards, dateProvider) = try makeRepositories(now: .at(2026, 3, 1, 9, 30))
    let deck = try decks.createDeck(named: "Spanish verbs")
    let knew = try #require(
      try cards.addCard(toDeckWithID: deck.id, front: "hablar", back: "to speak"))
    let again = try #require(
      try cards.addCard(toDeckWithID: deck.id, front: "comer", back: "to eat"))
    dateProvider.advance(by: 60)

    try cards.recordGrade(.knewIt, forCardWithID: knew.id)
    try cards.recordGrade(.again, forCardWithID: again.id)

    let seen = try cards.cards(inDeckWithID: deck.id).map(\.lastSeenAt)
    #expect(seen == [.at(2026, 3, 1, 9, 31), .at(2026, 3, 1, 9, 31)])
  }

  @Test("A Grade on one Card leaves the others alone")
  func gradingOneCardLeavesTheOthersAlone() throws {
    let (decks, cards, _) = try makeRepositories()
    let deck = try decks.createDeck(named: "Spanish verbs")
    let graded = try #require(
      try cards.addCard(toDeckWithID: deck.id, front: "hablar", back: "to speak"))
    try cards.addCard(toDeckWithID: deck.id, front: "comer", back: "to eat")

    try cards.recordGrade(.knewIt, forCardWithID: graded.id)

    let untouched = try #require(
      try cards.cards(inDeckWithID: deck.id).first { $0.front == "comer" })
    #expect(untouched.masteryStreak == 0)
    #expect(untouched.lastSeenAt == nil)
  }

  @Test("Grading a Card that is not there changes nothing")
  func gradingAMissingCardIsANoOp() throws {
    let (decks, cards, _) = try makeRepositories()
    let deck = try decks.createDeck(named: "Spanish verbs")
    try cards.addCard(toDeckWithID: deck.id, front: "hablar", back: "to speak")

    try cards.recordGrade(.knewIt, forCardWithID: UUID())

    #expect(try cards.cards(inDeckWithID: deck.id).first?.masteryStreak == 0)
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
}
