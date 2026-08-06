import Foundation
import SwiftData
import Testing

@testable import Flashcards

/// Driven the way Review drives it: start the Session, reveal, Grade, and look at what the model
/// publishes and at what the store holds afterwards. The repository underneath is the real
/// SwiftData one over an in-memory store, so a Grade that never lands is a failing test here.
///
/// **Translated from the Android suite** (`SessionViewModelTest.kt`), minus the cases that belong
/// to tickets this one does not carry — the chosen Session length is a Settings concern, and
/// nothing writes the Session log yet.
@MainActor
@Suite("Session model")
struct SessionModelTests {

  /// A Session over its own store, with `count` Cards in the Deck stamped a minute apart so the
  /// order they compose in is a fact rather than a coincidence of the fetch.
  private func makeSession(
    cards count: Int, length: Int = SessionModel.defaultLength
  ) throws -> (SessionModel, SwiftDataCardRepository, UUID) {
    let container = try ModelContainer.makeInMemoryContainer()
    let context = ModelContext(container)
    let dateProvider = FixedDateProvider(now: .at(2026, 3, 1, 9, 30))
    let decks = SwiftDataDeckRepository(context: context, dateProvider: dateProvider)
    let cards = SwiftDataCardRepository(context: context, dateProvider: dateProvider)
    let deck = try decks.createDeck(named: "Spanish verbs")
    for index in 0..<count {
      try cards.addCard(toDeckWithID: deck.id, front: "Front \(index)", back: "Back \(index)")
      dateProvider.advance(by: 60)
    }
    let model = SessionModel(deckID: deck.id, cardRepository: cards, length: length)
    return (model, cards, deck.id)
  }

  @Test("A Session runs Session-length Cards from the Deck, one at a time")
  func aSessionRunsSessionLengthCards() throws {
    let (model, _, _) = try makeSession(cards: 8)

    model.start()

    let reviewing = try #require(model.state.reviewing)
    #expect(reviewing.total == SessionModel.defaultLength)
    #expect(reviewing.position == 1)
    #expect(reviewing.card.front == "Front 0")
  }

  @Test("A Deck smaller than the Session length runs a shorter Session")
  func aSmallDeckRunsAShorterSession() throws {
    let (model, _, _) = try makeSession(cards: 2)

    model.start()

    #expect(model.state.reviewing?.total == 2)
  }

  @Test("Only the Front is showing until the Card is tapped")
  func theBackIsHiddenUntilItIsAskedFor() throws {
    let (model, _, _) = try makeSession(cards: 3)
    model.start()

    #expect(model.state.reviewing?.isRevealed == false)

    model.toggleReveal()

    #expect(model.state.reviewing?.isRevealed == true)
  }

  @Test("A second tap puts the Card face down again")
  func revealTogglesBack() throws {
    let (model, _, _) = try makeSession(cards: 3)
    model.start()
    model.toggleReveal()

    model.toggleReveal()

    #expect(model.state.reviewing?.isRevealed == false)
  }

  @Test("The next Card starts face down again")
  func theNextCardStartsFaceDown() throws {
    let (model, _, _) = try makeSession(cards: 3)
    model.start()
    model.toggleReveal()

    model.grade(.knewIt)

    let reviewing = try #require(model.state.reviewing)
    #expect(reviewing.position == 2)
    #expect(reviewing.isRevealed == false)
  }

  @Test("Position and progress run through the Session")
  func positionAndProgressRunThrough() throws {
    let (model, _, _) = try makeSession(cards: 3, length: 3)
    model.start()

    #expect(model.state.reviewing?.progress == 0)

    model.grade(.knewIt)

    #expect(model.state.reviewing?.position == 2)
    #expect(model.state.reviewing?.progress == 1.0 / 3.0)
  }

  @Test("No Card comes up twice in one Session")
  func noCardComesUpTwice() throws {
    let (model, _, _) = try makeSession(cards: 3, length: 3)
    model.start()

    var fronts: [String] = []
    for _ in 0..<3 {
      fronts.append(try #require(model.state.reviewing?.card.front))
      model.grade(.knewIt)
    }

    #expect(Set(fronts).count == fronts.count)
  }

  /// The mastery rule, seen from the screen that applies it — the Grade reaches the store, and
  /// `Again` on the Card after it does not carry the first one's streak with it.
  @Test("`Knew it` lifts the Card's Mastery streak and `Again` drops it")
  func gradesReachTheStore() throws {
    let (model, cards, deckID) = try makeSession(cards: 2, length: 2)
    model.start()

    model.grade(.knewIt)
    model.grade(.again)

    let streaks = try cards.cards(inDeckWithID: deckID)
      .sorted { $0.front < $1.front }
      .map(\.masteryStreak)
    #expect(streaks == [1, 0])
  }

  @Test("The last Grade ends the Session and scores the first pass")
  func theLastGradeFinishesTheSession() throws {
    let (model, _, _) = try makeSession(cards: 3, length: 3)
    model.start()

    model.grade(.knewIt)
    model.grade(.again)
    model.grade(.knewIt)

    let results = try #require(model.state.results)
    #expect(results.knewIt == 2)
    #expect(results.total == 3)
  }

  @Test("The results list every Miss and nothing else")
  func theResultsListTheMisses() throws {
    let (model, _, _) = try makeSession(cards: 3, length: 3)
    model.start()
    let missed = try #require(model.state.reviewing?.card.front)

    model.grade(.again)
    model.grade(.knewIt)
    model.grade(.knewIt)

    #expect(model.state.results?.misses.map(\.front) == [missed])
  }

  @Test("A Session with nothing Missed has an empty Miss list")
  func aCleanSessionHasNoMisses() throws {
    let (model, _, _) = try makeSession(cards: 2, length: 2)
    model.start()

    model.grade(.knewIt)
    model.grade(.knewIt)

    #expect(model.state.results?.misses.isEmpty == true)
  }

  /// The Misses are the Cards as they came up, so the list reads as what the user just saw rather
  /// than as what Grading them has since done to their streaks.
  @Test("Reviewing the Misses runs a Session of exactly those Cards")
  func reviewingTheMissesRunsThoseCards() throws {
    let (model, _, _) = try makeSession(cards: 4, length: 4)
    model.start()
    var missed: [String] = []
    for index in 0..<4 {
      if index.isMultiple(of: 2) {
        missed.append(try #require(model.state.reviewing?.card.front))
      }
      model.grade(index.isMultiple(of: 2) ? .again : .knewIt)
    }

    model.reviewMisses()

    let reviewing = try #require(model.state.reviewing)
    #expect(reviewing.total == missed.count)
    #expect(reviewing.card.front == missed.first)
    #expect(reviewing.position == 1)
    #expect(reviewing.isRevealed == false)
  }

  @Test("The Misses are scored on their own, not carried over")
  func theMissesAreScoredOnTheirOwn() throws {
    let (model, _, _) = try makeSession(cards: 3, length: 3)
    model.start()
    model.grade(.again)
    model.grade(.knewIt)
    model.grade(.knewIt)

    model.reviewMisses()
    model.grade(.knewIt)

    let results = try #require(model.state.results)
    #expect(results.knewIt == 1)
    #expect(results.total == 1)
    #expect(results.misses.isEmpty)
  }

  @Test("A Session with nothing Missed has nothing to re-review")
  func nothingMissedIsNothingToReview() throws {
    let (model, _, _) = try makeSession(cards: 2, length: 2)
    model.start()
    model.grade(.knewIt)
    model.grade(.knewIt)

    model.reviewMisses()

    #expect(model.state.results?.total == 2)
  }

  /// Stopping is always available and never costs anything: only the Cards that were Graded moved.
  @Test("Ending a Session early leaves the Cards it never reached alone")
  func endingEarlyLeavesTheRestAlone() throws {
    let (model, cards, deckID) = try makeSession(cards: 5)
    model.start()
    let graded = try #require(model.state.reviewing?.card.front)

    model.grade(.knewIt)

    let untouched = try cards.cards(inDeckWithID: deckID).filter { $0.front != graded }
    #expect(untouched.allSatisfy { $0.masteryStreak == 0 })
    #expect(untouched.allSatisfy { $0.lastSeenAt == nil })
  }

  /// A Session the user is part-way through must not reshuffle underneath them because a Grade
  /// they just gave changed what the Deck would compose now.
  @Test("The Cards are drawn once, when the Session starts")
  func theSessionIsDrawnOnce() throws {
    let (model, _, _) = try makeSession(cards: 8)
    model.start()
    model.grade(.knewIt)
    let secondCard = try #require(model.state.reviewing?.card.front)

    model.start()

    #expect(model.state.reviewing?.card.front == secondCard)
    #expect(model.state.reviewing?.position == 2)
  }

  @Test("A Deck with no Cards has no Session to run")
  func anEmptyDeckHasNoSession() throws {
    let (model, _, _) = try makeSession(cards: 0)

    model.start()

    #expect(model.state == .empty)
  }

  /// Deleting the Deck took its Cards with it, so there is nothing left to draw.
  @Test("A Deck that is already gone has no Session to run")
  func aDeletedDeckHasNoSession() throws {
    let model = SessionModel(
      deckID: UUID(),
      cardRepository: try makeSession(cards: 3).1,
      length: SessionModel.defaultLength)

    model.start()

    #expect(model.state == .empty)
  }

  @Test("A store that cannot be read says so rather than posing as an empty Deck")
  func aFailedReadIsNotAnEmptyDeck() {
    let model = SessionModel(deckID: UUID(), cardRepository: FailingCardRepository())

    model.start()

    #expect(model.state == .failed)
  }

  /// A Grade that could not be written is the silent data loss this whole feature exists to avoid,
  /// so the Session says so rather than moving on as though it had landed.
  @Test("A Grade that cannot be written says so rather than moving on to the next Card")
  func aFailedGradeIsReported() {
    let model = SessionModel(
      deckID: UUID(),
      cardRepository: GradeFailingCardRepository(
        cards: [
          CardSummary(
            id: UUID(), front: "hablar", back: "to speak", masteryStreak: 0, lastSeenAt: nil,
            createdAt: .at(2026, 3, 1))
        ]))
    model.start()

    model.grade(.knewIt)

    #expect(model.state == .failed)
  }
}
