import Foundation
import SwiftData
import Testing

@testable import Flashcards

/// The first tests in the suite. They exist to establish the two conventions everything else
/// copies — an in-memory container over the real schema, and a hand-written fake for the one
/// seam that exists so far — and to fail loudly if either stops working.
@Suite("App scaffold")
struct AppScaffoldTests {

  @Test("The in-memory container opens over the real schema and starts empty")
  func inMemoryContainerStartsEmpty() throws {
    let container = try ModelContainer.makeInMemoryContainer()
    let context = ModelContext(container)

    #expect(try context.fetchCount(FetchDescriptor<Deck>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<Card>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<SessionRecord>()) == 0)
  }

  @Test("A Deck saved to the container is read back")
  func deckRoundTrips() throws {
    let container = try ModelContainer.makeInMemoryContainer()
    let context = ModelContext(container)

    context.insert(Deck(name: "Spanish verbs", createdAt: .at(2026, 3, 1)))
    try context.save()

    let decks = try context.fetch(FetchDescriptor<Deck>())
    #expect(decks.count == 1)
    #expect(decks.first?.name == "Spanish verbs")
  }

  @Test("Deleting a Deck deletes its Cards")
  func deletingADeckCascadesToItsCards() throws {
    let container = try ModelContainer.makeInMemoryContainer()
    let context = ModelContext(container)

    let deck = Deck(name: "Spanish verbs", createdAt: .at(2026, 3, 1))
    context.insert(deck)
    deck.cards.append(Card(front: "hablar", back: "to speak", createdAt: .at(2026, 3, 1)))
    deck.cards.append(Card(front: "comer", back: "to eat", createdAt: .at(2026, 3, 1)))
    try context.save()
    #expect(try context.fetchCount(FetchDescriptor<Card>()) == 2)

    context.delete(deck)
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<Deck>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<Card>()) == 0)
  }

  @Test("A new Card starts with a Mastery streak of zero")
  func newCardStartsAtZeroStreak() {
    let card = Card(front: "hablar", back: "to speak", createdAt: .at(2026, 3, 1))

    #expect(card.masteryStreak == 0)
    #expect(card.lastSeenAt == nil)
  }

  @Test("The fake date provider returns the instant it was given, and moves only when asked")
  func fixedDateProviderIsStable() {
    let dateProvider = FixedDateProvider(now: .at(2026, 3, 1, 9, 30))

    #expect(dateProvider.now == .at(2026, 3, 1, 9, 30))
    #expect(dateProvider.now == .at(2026, 3, 1, 9, 30))

    dateProvider.advance(by: 60 * 60 * 24)
    #expect(dateProvider.now == .at(2026, 3, 2, 9, 30))
  }
}
