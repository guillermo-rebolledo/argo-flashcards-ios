import Foundation
import SwiftData
import Testing

@testable import Flashcards

/// The repository is driven against the real schema in an in-memory container — there is no fake
/// store. Every assertion here is on what a *subsequent read* returns, never on which method the
/// context was asked for, so a rewrite of the fetch or the model survives these tests untouched.
@Suite("Deck repository")
struct DeckRepositoryTests {

  /// Builds a repository over its own empty in-memory store.
  private func makeRepository(
    now: Date = .at(2026, 3, 1, 9, 30)
  ) throws -> (SwiftDataDeckRepository, FixedDateProvider) {
    let container = try ModelContainer.makeInMemoryContainer()
    let dateProvider = FixedDateProvider(now: now)
    let repository = SwiftDataDeckRepository(
      context: ModelContext(container), dateProvider: dateProvider)
    return (repository, dateProvider)
  }

  @Test("A fresh store has no Decks")
  func startsEmpty() throws {
    let (repository, _) = try makeRepository()

    #expect(try repository.decks().isEmpty)
  }

  @Test("A created Deck is returned by the next read, with the name it was given")
  func createdDeckIsRead() throws {
    let (repository, _) = try makeRepository()

    try repository.createDeck(named: "Spanish verbs")

    let decks = try repository.decks()
    #expect(decks.count == 1)
    #expect(decks.first?.name == "Spanish verbs")
  }

  @Test("A created Deck is stamped with the current instant")
  func createdDeckIsStamped() throws {
    let (repository, _) = try makeRepository(now: .at(2026, 3, 1, 9, 30))

    let deck = try repository.createDeck(named: "Spanish verbs")

    #expect(deck.createdAt == .at(2026, 3, 1, 9, 30))
  }

  @Test("Decks are listed newest first, so a Deck just created is at the top")
  func decksAreListedNewestFirst() throws {
    let (repository, dateProvider) = try makeRepository(now: .at(2026, 3, 1, 9, 30))

    try repository.createDeck(named: "Spanish verbs")
    dateProvider.advance(by: 60 * 60 * 24)
    try repository.createDeck(named: "Kanji")

    #expect(try repository.decks().map(\.name) == ["Kanji", "Spanish verbs"])
  }

  @Test("Two Decks may share a name and remain separate Decks")
  func decksWithTheSameNameAreDistinct() throws {
    let (repository, _) = try makeRepository()

    let first = try repository.createDeck(named: "Spanish verbs")
    let second = try repository.createDeck(named: "Spanish verbs")

    #expect(first.id != second.id)
    #expect(try repository.decks().count == 2)
  }

  @Test("A renamed Deck reads back under its new name, keeping its identity and timestamp")
  func renameIsRead() throws {
    let (repository, _) = try makeRepository()
    let deck = try repository.createDeck(named: "Spanish verbs")

    try repository.rename(deckWithID: deck.id, to: "Spanish irregular verbs")

    let renamed = try #require(try repository.decks().first)
    #expect(renamed.name == "Spanish irregular verbs")
    #expect(renamed.id == deck.id)
    #expect(renamed.createdAt == deck.createdAt)
  }

  @Test("Renaming leaves every other Deck alone")
  func renameTouchesOneDeck() throws {
    let (repository, dateProvider) = try makeRepository()
    let deck = try repository.createDeck(named: "Spanish verbs")
    dateProvider.advance(by: 60)
    try repository.createDeck(named: "Kanji")

    try repository.rename(deckWithID: deck.id, to: "Spanish irregular verbs")

    #expect(try repository.decks().map(\.name) == ["Kanji", "Spanish irregular verbs"])
  }

  @Test("A deleted Deck is gone from the next read")
  func deleteIsRead() throws {
    let (repository, dateProvider) = try makeRepository()
    let deck = try repository.createDeck(named: "Spanish verbs")
    dateProvider.advance(by: 60)
    try repository.createDeck(named: "Kanji")

    try repository.delete(deckWithID: deck.id)

    #expect(try repository.decks().map(\.name) == ["Kanji"])
  }

  @Test("Deleting a Deck deletes its Cards")
  func deleteCascadesToCards() throws {
    let container = try ModelContainer.makeInMemoryContainer()
    let context = ModelContext(container)
    let repository = SwiftDataDeckRepository(
      context: context, dateProvider: FixedDateProvider(now: .at(2026, 3, 1)))
    let deck = try repository.createDeck(named: "Spanish verbs")

    let stored = try #require(
      try context.fetch(FetchDescriptor<Deck>()).first { $0.id == deck.id })
    stored.cards.append(Card(front: "hablar", back: "to speak", createdAt: .at(2026, 3, 1)))
    try context.save()

    try repository.delete(deckWithID: deck.id)

    #expect(try context.fetchCount(FetchDescriptor<Card>()) == 0)
  }

  @Test("Renaming or deleting a Deck that is not there changes nothing")
  func operationsOnAMissingDeckAreNoOps() throws {
    let (repository, _) = try makeRepository()
    try repository.createDeck(named: "Spanish verbs")

    try repository.rename(deckWithID: UUID(), to: "Kanji")
    try repository.delete(deckWithID: UUID())

    #expect(try repository.decks().map(\.name) == ["Spanish verbs"])
  }

  @Test("Decks written by one repository are read by the next one over the same store")
  func decksSurviveANewRepositoryOverTheSameStore() throws {
    let container = try ModelContainer.makeInMemoryContainer()
    let dateProvider = FixedDateProvider(now: .at(2026, 3, 1))
    let writer = SwiftDataDeckRepository(
      context: ModelContext(container), dateProvider: dateProvider)

    try writer.createDeck(named: "Spanish verbs")

    let reader = SwiftDataDeckRepository(
      context: ModelContext(container), dateProvider: dateProvider)
    #expect(try reader.decks().map(\.name) == ["Spanish verbs"])
  }

  /// The one test in the suite that touches the disk.
  ///
  /// Everything else runs in memory, which proves a Deck survives a new context but not that it
  /// survives the process — an in-memory store dies with the container either way. Relaunching is
  /// modelled the only way a unit test can: write through one container, drop it, open a second
  /// one over the same file, and read. It is the same on-disk configuration the app runs on, at a
  /// temporary path so the suite never touches a real store and leaves nothing behind.
  @Test("Decks written to a store on disk are read back by a container opened over it later")
  func decksSurviveTheStoreBeingClosedAndReopened() throws {
    let storeURL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).store")
    let configuration = ModelConfiguration(schema: AppSchema.schema, url: storeURL)
    let dateProvider = FixedDateProvider(now: .at(2026, 3, 1))

    try {
      let container = try ModelContainer(for: AppSchema.schema, configurations: configuration)
      let repository = SwiftDataDeckRepository(
        context: ModelContext(container), dateProvider: dateProvider)
      try repository.createDeck(named: "Spanish verbs")
    }()

    let reopened = try ModelContainer(for: AppSchema.schema, configurations: configuration)
    let repository = SwiftDataDeckRepository(
      context: ModelContext(reopened), dateProvider: dateProvider)
    #expect(try repository.decks().map(\.name) == ["Spanish verbs"])

    try? FileManager.default.removeItem(at: storeURL)
  }
}
