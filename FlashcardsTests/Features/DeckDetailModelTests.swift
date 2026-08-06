import Foundation
import SwiftData
import Testing

@testable import Flashcards

/// Driven the way the screen drives it: call an action, then look at the state and the Deck name
/// the model publishes. The repositories underneath are the real SwiftData ones over an in-memory
/// store, so these cover the model and the store together.
@MainActor
@Suite("Deck detail model")
struct DeckDetailModelTests {

  /// A model over its own store, holding one Deck. The context comes back so a test can put
  /// mastery on a Card — nothing writes a Mastery streak yet, and the filter needs Cards that
  /// have one.
  private func makeModel(
    deckNamed name: String = "Spanish verbs",
    now: Date = .at(2026, 3, 1, 9, 30)
  ) throws -> (DeckDetailModel, ModelContext, FixedDateProvider) {
    let container = try ModelContainer.makeInMemoryContainer()
    let context = ModelContext(container)
    let dateProvider = FixedDateProvider(now: now)
    let decks = SwiftDataDeckRepository(context: context, dateProvider: dateProvider)
    let cards = SwiftDataCardRepository(context: context, dateProvider: dateProvider)
    let deck = try decks.createDeck(named: name)
    let model = DeckDetailModel(deck: deck, deckRepository: decks, cardRepository: cards)
    return (model, context, dateProvider)
  }

  @Test("Before anything is loaded the screen is in its loading state, under the Deck's name")
  func startsLoading() throws {
    let (model, _, _) = try makeModel(deckNamed: "Spanish verbs")

    #expect(model.state == .loading)
    #expect(model.deckName == "Spanish verbs")
  }

  @Test("A Deck with no Cards lands on the empty-Deck state, not an empty list")
  func aDeckWithNoCardsIsEmpty() throws {
    let (model, _, _) = try makeModel()

    model.load()

    #expect(model.state == .empty)
  }

  @Test("Adding a Card puts it in the list")
  func addShowsTheCard() throws {
    let (model, _, _) = try makeModel()
    model.load()

    model.addCard(front: "hablar", back: "to speak")

    #expect(model.state.contents?.cards.map(\.front) == ["hablar"])
    #expect(model.state.contents?.cards.first?.back == "to speak")
  }

  @Test("Cards added so far stay listed while more are added, newest first")
  func addedCardsStayVisible() throws {
    let (model, _, dateProvider) = try makeModel()
    model.load()

    model.addCard(front: "hablar", back: "to speak")
    dateProvider.advance(by: 60)
    model.addCard(front: "comer", back: "to eat")

    #expect(model.state.contents?.cards.map(\.front) == ["comer", "hablar"])
  }

  @Test("A Card's Front and Back are trimmed of surrounding whitespace")
  func addTrimsBothSides() throws {
    let (model, _, _) = try makeModel()
    model.load()

    model.addCard(front: "  hablar\n", back: "\tto speak  ")

    #expect(model.state.contents?.cards.first?.front == "hablar")
    #expect(model.state.contents?.cards.first?.back == "to speak")
  }

  @Test("A Card needs both a Front and a Back — a blank either side adds nothing")
  func aBlankSideAddsNothing() throws {
    let (model, _, _) = try makeModel()
    model.load()

    model.addCard(front: "   ", back: "to speak")
    model.addCard(front: "hablar", back: "  ")

    #expect(model.state == .empty)
  }

  @Test("The mastery summary counts the Mastered Cards against every Card in the Deck")
  func masterySummaryCountsTheWholeDeck() throws {
    let (model, context, _) = try makeModel()
    model.load()
    model.addCard(front: "hablar", back: "to speak")
    model.addCard(front: "comer", back: "to eat")
    model.addCard(front: "vivir", back: "to live")
    try setStreak(3, onCardWithFront: "hablar", in: context)
    model.load()

    #expect(model.state.contents?.masteredCount == 1)
    #expect(model.state.contents?.cardCount == 3)
  }

  @Test("A Card is Mastered at a streak of three, and Learning below it")
  func masteryThresholdIsThree() throws {
    let (model, context, _) = try makeModel()
    model.load()
    model.addCard(front: "hablar", back: "to speak")
    model.addCard(front: "comer", back: "to eat")
    try setStreak(2, onCardWithFront: "hablar", in: context)
    try setStreak(3, onCardWithFront: "comer", in: context)
    model.load()

    let cards = try #require(model.state.contents?.cards)
    #expect(cards.first { $0.front == "hablar" }?.isMastered == false)
    #expect(cards.first { $0.front == "comer" }?.isMastered == true)
  }

  @Test("The All filter lists every Card in the Deck")
  func allFilterListsEverything() throws {
    let (model, context, _) = try makeModel()
    try makeMixedDeck(model, context)

    model.show(.all)

    #expect(model.filter == .all)
    #expect(model.state.contents?.cards.map(\.front).sorted() == ["comer", "hablar", "vivir"])
  }

  @Test("The Learning filter lists only the Cards below the mastery threshold")
  func learningFilterListsUnmasteredCards() throws {
    let (model, context, _) = try makeModel()
    try makeMixedDeck(model, context)

    model.show(.learning)

    #expect(model.state.contents?.cards.map(\.front).sorted() == ["comer", "vivir"])
  }

  @Test("The Mastered filter lists only the Cards at or above the mastery threshold")
  func masteredFilterListsMasteredCards() throws {
    let (model, context, _) = try makeModel()
    try makeMixedDeck(model, context)

    model.show(.mastered)

    #expect(model.state.contents?.cards.map(\.front) == ["hablar"])
  }

  @Test("A filter matching nothing shows a Deck with no matching Cards, not an empty Deck")
  func aFilterMatchingNothingIsNotAnEmptyDeck() throws {
    let (model, _, _) = try makeModel()
    model.load()
    model.addCard(front: "hablar", back: "to speak")

    model.show(.mastered)

    #expect(model.state.contents?.cards.isEmpty == true)
    #expect(model.state.contents?.cardCount == 1)
    #expect(model.state != .empty)
  }

  @Test("The summary counts the whole Deck even while a filter is narrowing the list")
  func theSummaryIgnoresTheFilter() throws {
    let (model, context, _) = try makeModel()
    try makeMixedDeck(model, context)

    model.show(.mastered)

    #expect(model.state.contents?.cards.count == 1)
    #expect(model.state.contents?.masteredCount == 1)
    #expect(model.state.contents?.cardCount == 3)
  }

  @Test("A Card added while a filter is on is listed if it matches it")
  func addingUnderAFilterRespectsIt() throws {
    let (model, _, _) = try makeModel()
    model.load()
    model.show(.learning)

    model.addCard(front: "hablar", back: "to speak")

    #expect(model.state.contents?.cards.map(\.front) == ["hablar"])
  }

  @Test("Editing a Card shows its new Front and Back")
  func editShowsTheNewContent() throws {
    let (model, _, _) = try makeModel()
    model.load()
    model.addCard(front: "hablar", back: "to speek")
    let card = try #require(model.state.contents?.cards.first)

    model.updateCard(card, front: "hablar", back: "to speak")

    #expect(model.state.contents?.cards.map(\.back) == ["to speak"])
    #expect(model.state.contents?.cards.first?.id == card.id)
  }

  /// The rule the ticket asks for by name: fixing a typo must not cost a learner their progress.
  @Test("Editing a Card leaves its Mastery streak untouched, so it stays Mastered")
  func editLeavesTheMasteryStreakAlone() throws {
    let (model, context, _) = try makeModel()
    model.load()
    model.addCard(front: "hablar", back: "to speek")
    try setStreak(3, onCardWithFront: "hablar", in: context)
    model.load()
    let card = try #require(model.state.contents?.cards.first)

    model.updateCard(card, front: "hablar", back: "to speak")

    let edited = try #require(model.state.contents?.cards.first)
    #expect(edited.masteryStreak == 3)
    #expect(edited.isMastered)
    #expect(model.state.contents?.masteredCount == 1)
  }

  @Test("Editing a Card to a blank Front or Back leaves it as it was")
  func editToBlankIsIgnored() throws {
    let (model, _, _) = try makeModel()
    model.load()
    model.addCard(front: "hablar", back: "to speak")
    let card = try #require(model.state.contents?.cards.first)

    model.updateCard(card, front: "  ", back: "to speak")
    model.updateCard(card, front: "hablar", back: "\n")

    #expect(model.state.contents?.cards.map(\.front) == ["hablar"])
    #expect(model.state.contents?.cards.map(\.back) == ["to speak"])
  }

  @Test("Deleting a Card removes it from the list")
  func deleteRemovesTheCard() throws {
    let (model, _, dateProvider) = try makeModel()
    model.load()
    model.addCard(front: "hablar", back: "to speak")
    dateProvider.advance(by: 60)
    model.addCard(front: "comer", back: "to eat")
    let comer = try #require(model.state.contents?.cards.first { $0.front == "comer" })

    model.deleteCard(comer)

    #expect(model.state.contents?.cards.map(\.front) == ["hablar"])
  }

  @Test("Deleting the last Card returns the screen to the empty-Deck state")
  func deletingTheLastCardIsEmptyAgain() throws {
    let (model, _, _) = try makeModel()
    model.load()
    model.addCard(front: "hablar", back: "to speak")
    let card = try #require(model.state.contents?.cards.first)

    model.deleteCard(card)

    #expect(model.state == .empty)
  }

  @Test("Renaming the Deck shows it under its new name")
  func renameShowsTheNewName() throws {
    let (model, _, _) = try makeModel(deckNamed: "Spanish verbs")
    model.load()

    model.renameDeck(to: "  Spanish irregular verbs ")

    #expect(model.deckName == "Spanish irregular verbs")
  }

  @Test("Renaming the Deck to a blank name leaves its name as it was")
  func renameToBlankIsIgnored() throws {
    let (model, _, _) = try makeModel(deckNamed: "Spanish verbs")
    model.load()

    model.renameDeck(to: "   ")

    #expect(model.deckName == "Spanish verbs")
  }

  @Test("Deleting the Deck leaves the screen with nothing to show, and takes its Cards with it")
  func deletingTheDeckLeavesNothing() throws {
    let (model, context, _) = try makeModel()
    model.load()
    model.addCard(front: "hablar", back: "to speak")

    model.deleteDeck()

    #expect(model.state == .gone)
    #expect(try context.fetchCount(FetchDescriptor<Card>()) == 0)
  }

  @Test("A Deck deleted from under the screen reads as gone rather than as an empty Deck")
  func aDeckDeletedElsewhereIsGone() throws {
    let container = try ModelContainer.makeInMemoryContainer()
    let context = ModelContext(container)
    let dateProvider = FixedDateProvider(now: .at(2026, 3, 1))
    let decks = SwiftDataDeckRepository(context: context, dateProvider: dateProvider)
    let cards = SwiftDataCardRepository(context: context, dateProvider: dateProvider)
    let deck = try decks.createDeck(named: "Spanish verbs")
    let model = DeckDetailModel(deck: deck, deckRepository: decks, cardRepository: cards)
    model.load()

    try decks.delete(deckWithID: deck.id)
    model.load()

    #expect(model.state == .gone)
  }

  @Test("A store that cannot be read says so rather than posing as an empty Deck")
  func aFailedReadIsNotAnEmptyDeck() {
    let model = DeckDetailModel(
      deck: DeckSummary(id: UUID(), name: "Spanish verbs", createdAt: .at(2026, 3, 1)),
      deckRepository: FailingDeckRepository(),
      cardRepository: FailingCardRepository())

    model.load()

    #expect(model.state == .failed)
  }

  @Test("A write that cannot be made says so rather than showing a list it did not land in")
  func aFailedWriteIsReported() throws {
    let container = try ModelContainer.makeInMemoryContainer()
    let dateProvider = FixedDateProvider(now: .at(2026, 3, 1))
    let decks = SwiftDataDeckRepository(
      context: ModelContext(container), dateProvider: dateProvider)
    let deck = try decks.createDeck(named: "Spanish verbs")
    let model = DeckDetailModel(
      deck: deck, deckRepository: decks, cardRepository: WriteFailingCardRepository())
    model.load()
    #expect(model.state == .empty)

    model.addCard(front: "hablar", back: "to speak")

    #expect(model.state == .failed)
  }

  /// Three Cards, one of them Mastered, loaded and ready to be filtered.
  private func makeMixedDeck(_ model: DeckDetailModel, _ context: ModelContext) throws {
    model.load()
    model.addCard(front: "hablar", back: "to speak")
    model.addCard(front: "comer", back: "to eat")
    model.addCard(front: "vivir", back: "to live")
    try setStreak(3, onCardWithFront: "hablar", in: context)
    model.load()
  }

  /// Grading is MEM-104's work. Until it exists, a Mastered Card is made by writing the streak
  /// the filter reads — the alternative is a filter tested only against Cards that are all
  /// Learning, which would not test it at all.
  private func setStreak(
    _ streak: Int, onCardWithFront front: String, in context: ModelContext
  ) throws {
    let card = try #require(
      try context.fetch(FetchDescriptor<Card>()).first { $0.front == front })
    card.masteryStreak = streak
    try context.save()
  }
}
