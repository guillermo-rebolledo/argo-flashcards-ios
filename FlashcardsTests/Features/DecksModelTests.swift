import Foundation
import SwiftData
import Testing

@testable import Flashcards

/// The screen model is driven the way the screen drives it — call an action, then look at the
/// single state it publishes. The repository underneath is the real SwiftData one over an
/// in-memory store, so these tests cover the model and the store together and there is nothing to
/// drift between them.
@MainActor
@Suite("Decks screen model")
struct DecksModelTests {

  /// A model over its own empty in-memory store, with the clock the store stamps Decks from.
  private func makeModel(
    now: Date = .at(2026, 3, 1, 9, 30)
  ) throws -> (DecksModel, FixedDateProvider) {
    let container = try ModelContainer.makeInMemoryContainer()
    let dateProvider = FixedDateProvider(now: now)
    let repository = SwiftDataDeckRepository(
      context: ModelContext(container), dateProvider: dateProvider)
    return (DecksModel(repository: repository), dateProvider)
  }

  @Test("Before anything is loaded the screen is in its loading state")
  func startsLoading() throws {
    let (model, _) = try makeModel()

    #expect(model.state == .loading)
    #expect(model.state.decks == nil)
  }

  @Test("A first launch with no Decks lands on the empty state, not an empty list")
  func firstLaunchIsEmpty() throws {
    let (model, _) = try makeModel()

    model.load()

    #expect(model.state == .empty)
  }

  @Test("Creating a Deck puts it in the list")
  func createShowsTheDeck() throws {
    let (model, _) = try makeModel()
    model.load()

    model.createDeck(named: "Spanish verbs")

    #expect(model.state.decks?.map(\.name) == ["Spanish verbs"])
  }

  @Test("A Deck name is trimmed of surrounding whitespace")
  func createTrimsTheName() throws {
    let (model, _) = try makeModel()
    model.load()

    model.createDeck(named: "  Spanish verbs\n")

    #expect(model.state.decks?.map(\.name) == ["Spanish verbs"])
  }

  @Test("A blank name creates nothing and leaves the empty state in place")
  func blankNameCreatesNothing() throws {
    let (model, _) = try makeModel()
    model.load()

    model.createDeck(named: "   ")

    #expect(model.state == .empty)
  }

  @Test("Renaming a Deck shows it under its new name")
  func renameShowsTheNewName() throws {
    let (model, _) = try makeModel()
    model.load()
    model.createDeck(named: "Spanish verbs")
    let deck = try #require(model.state.decks?.first)

    model.rename(deck, to: "Spanish irregular verbs")

    #expect(model.state.decks?.map(\.name) == ["Spanish irregular verbs"])
    #expect(model.state.decks?.first?.id == deck.id)
  }

  @Test("Renaming to a blank name leaves the Deck as it was")
  func renameToBlankIsIgnored() throws {
    let (model, _) = try makeModel()
    model.load()
    model.createDeck(named: "Spanish verbs")
    let deck = try #require(model.state.decks?.first)

    model.rename(deck, to: "  ")

    #expect(model.state.decks?.map(\.name) == ["Spanish verbs"])
  }

  @Test("Deleting a Deck removes it from the list")
  func deleteRemovesTheDeck() throws {
    let (model, dateProvider) = try makeModel()
    model.load()
    model.createDeck(named: "Spanish verbs")
    dateProvider.advance(by: 60)
    model.createDeck(named: "Kanji")
    let kanji = try #require(model.state.decks?.first { $0.name == "Kanji" })

    model.delete(kanji)

    #expect(model.state.decks?.map(\.name) == ["Spanish verbs"])
  }

  @Test("Deleting the last Deck returns the screen to the empty state")
  func deletingTheLastDeckIsEmptyAgain() throws {
    let (model, _) = try makeModel()
    model.load()
    model.createDeck(named: "Spanish verbs")
    let deck = try #require(model.state.decks?.first)

    model.delete(deck)

    #expect(model.state == .empty)
  }

  @Test("Decks written in one run of the screen are there when the screen is built again")
  func decksSurviveANewModelOverTheSameStore() throws {
    let container = try ModelContainer.makeInMemoryContainer()
    let dateProvider = FixedDateProvider(now: .at(2026, 3, 1))
    let first = DecksModel(
      repository: SwiftDataDeckRepository(
        context: ModelContext(container), dateProvider: dateProvider))
    first.load()
    first.createDeck(named: "Spanish verbs")

    let second = DecksModel(
      repository: SwiftDataDeckRepository(
        context: ModelContext(container), dateProvider: dateProvider))
    second.load()

    #expect(second.state.decks?.map(\.name) == ["Spanish verbs"])
  }

  @Test("A store that cannot be read says so rather than posing as a first launch")
  func aFailedReadIsNotAnEmptyState() {
    let model = DecksModel(repository: FailingDeckRepository())

    model.load()

    #expect(model.state == .failed)
  }
}
