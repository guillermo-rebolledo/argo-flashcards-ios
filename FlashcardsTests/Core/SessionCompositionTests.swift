import Foundation
import Testing

@testable import Flashcards

/// The one place a silent bug corrupts user data over weeks with no visible symptom — a Card that
/// quietly never resurfaces. Every case the rule has is written down here.
///
/// **Translated from the Android suite** (`SessionCompositionTest.kt`): same Deck shapes, same
/// expected orders. That translation is the specific mitigation for the spec's choice of two
/// implementations over a shared core — it turns "the two apps should agree" into a failing test
/// when they do not.
///
/// One difference is forced by the data model rather than chosen. Android breaks its last tie on
/// the Card's row id, which is assigned in creation order; a `UUID` carries no such order, so the
/// tie is broken on the created timestamp here. The Cards below are stamped a minute apart in
/// index order, so "id 1 before id 2" over there and "Front 1 before Front 2" here are the same
/// assertion.
@Suite("Session composition")
struct SessionCompositionTests {

  private let start = Date.at(2026, 3, 1, 9, 30)

  @Test("A Session is Session-length Cards long")
  func aSessionIsSessionLengthLong() {
    let deck = (1...20).map { learning($0) }

    #expect(composeSession(from: deck, length: 5).count == 5)
    #expect(composeSession(from: deck, length: 3).count == 3)
    #expect(composeSession(from: deck, length: 10).count == 10)
  }

  @Test("No Card appears in a Session twice")
  func noCardAppearsTwice() {
    let deck = (1...10).map { learning($0) }

    let ids = composeSession(from: deck, length: 10).map(\.id)

    #expect(Set(ids).count == ids.count)
  }

  @Test("Learning Cards come in lowest Mastery streak first")
  func learningCardsComeWeakestFirst() {
    let deck = [
      learning(1, streak: 2),
      learning(2, streak: 0),
      learning(3, streak: 1),
    ]

    #expect(fronts(composeSession(from: deck, length: 3)) == ["Front 2", "Front 3", "Front 1"])
  }

  @Test("Learning Cards on the same streak come oldest last-seen first")
  func learningCardsOnTheSameStreakComeOldestFirst() {
    let deck = [
      learning(1, seenAt: minutesIn(30)),
      learning(2, seenAt: minutesIn(10)),
      learning(3, seenAt: minutesIn(20)),
    ]

    #expect(fronts(composeSession(from: deck, length: 3)) == ["Front 2", "Front 3", "Front 1"])
  }

  /// A Card that has never been through a Review is the oldest thing there is.
  @Test("A Card that has never been seen comes before one that has")
  func aNeverSeenCardComesFirst() {
    let deck = [
      learning(1, seenAt: minutesIn(10)),
      learning(2, seenAt: nil),
    ]

    #expect(fronts(composeSession(from: deck, length: 2)) == ["Front 2", "Front 1"])
  }

  /// The streak is the first sort key, so a never-seen Card does not jump a weaker one.
  @Test("The streak is compared before last-seen")
  func theStreakIsComparedFirst() {
    let deck = [
      learning(1, streak: 1, seenAt: nil),
      learning(2, streak: 0, seenAt: minutesIn(10)),
    ]

    #expect(fronts(composeSession(from: deck, length: 2)) == ["Front 2", "Front 1"])
  }

  @Test("Every fifth slot draws a Mastered Card")
  func everyFifthSlotIsMastered() {
    let deck = (1...12).map { learning($0) } + (101...104).map { mastered($0) }

    let session = composeSession(from: deck, length: 10)

    #expect(everyFifth(session) == ["Front 101", "Front 102"])
    #expect(session.count { !$0.isMastered } == 8)
  }

  @Test("Mastered Cards come oldest last-seen first")
  func masteredCardsComeOldestFirst() {
    let deck =
      (1...12).map { learning($0) } + [
        mastered(101, seenAt: minutesIn(30)),
        mastered(102, seenAt: minutesIn(10)),
      ]

    #expect(everyFifth(composeSession(from: deck, length: 10)) == ["Front 102", "Front 101"])
  }

  /// The first four slots are Learning, so a Session of 3 or 4 has no Mastered slot in it.
  @Test("A Session shorter than five has no Mastered slot")
  func aShortSessionHasNoMasteredSlot() {
    let deck = (1...3).map { learning($0) } + (101...103).map { mastered($0) }

    #expect(fronts(composeSession(from: deck, length: 3)) == ["Front 1", "Front 2", "Front 3"])
  }

  @Test("A Deck with no Mastered Cards yields an all-Learning Session")
  func aDeckWithNothingMasteredIsAllLearning() {
    let deck = (1...10).map { learning($0) }

    #expect(fronts(composeSession(from: deck, length: 10)) == (1...10).map { "Front \($0)" })
  }

  @Test("A fully Mastered Deck yields an all-Mastered Session")
  func aFullyMasteredDeckIsAllMastered() {
    let deck = (101...110).map { mastered($0) }

    #expect(fronts(composeSession(from: deck, length: 5)) == (101...105).map { "Front \($0)" })
  }

  /// Two Learning Cards and plenty Mastered: the Learning slots fall through, not go short.
  @Test("Learning slots fall through to Mastered once the Learning Cards run out")
  func learningSlotsFallThroughToMastered() {
    let deck = [learning(1), learning(2)] + (101...110).map { mastered($0) }

    #expect(
      fronts(composeSession(from: deck, length: 5))
        == ["Front 1", "Front 2", "Front 101", "Front 102", "Front 103"])
  }

  /// The Mastered slot falls through too, rather than leaving a hole at position five.
  @Test("The fifth slot falls through to Learning when nothing is Mastered")
  func theMasteredSlotFallsThroughToLearning() {
    let deck = (1...6).map { learning($0) }

    #expect(fronts(composeSession(from: deck, length: 6)) == (1...6).map { "Front \($0)" })
  }

  @Test("A Deck smaller than the Session length gives every Card it has, once")
  func aSmallDeckGivesEveryCardOnce() {
    let deck = [learning(1), learning(2), mastered(101)]

    #expect(
      fronts(composeSession(from: deck, length: 5)) == ["Front 1", "Front 2", "Front 101"])
  }

  @Test("An empty Deck yields an empty Session")
  func anEmptyDeckYieldsAnEmptySession() {
    #expect(composeSession(from: [], length: 5).isEmpty)
  }

  /// Ordering is by the Card set alone: same Cards in, same Session out, every time.
  @Test("The same Deck composes the same Session however the Cards arrive")
  func compositionDoesNotDependOnTheOrderCardsArriveIn() {
    let deck = (1...12).map { learning($0, streak: $0 % 3) } + (101...104).map { mastered($0) }

    let first = composeSession(from: deck, length: 10)
    let second = composeSession(from: deck.reversed(), length: 10)

    #expect(fronts(first) == fronts(second))
  }

  /// Where Android has a row id to fall back on, this has none — so Cards alike in every ordered
  /// field must still compose the same Session rather than whichever order the fetch returned.
  @Test("Cards alike in streak, last-seen and creation still compose the same Session")
  func indistinguishableCardsStillComposeDeterministically() {
    let deck = (1...6).map { _ in
      CardSummary(
        id: UUID(), front: "Front", back: "Back", masteryStreak: 0, lastSeenAt: nil,
        createdAt: start)
    }

    let first = composeSession(from: deck, length: 5).map(\.id)
    let second = composeSession(from: deck.reversed(), length: 5).map(\.id)

    #expect(first == second)
  }

  private func learning(_ index: Int, streak: Int = 0, seenAt: Date? = nil) -> CardSummary {
    precondition(streak < Card.masteryThreshold, "Front \(index) is not a Learning Card")
    return card(index, streak: streak, seenAt: seenAt)
  }

  private func mastered(_ index: Int, seenAt: Date? = nil) -> CardSummary {
    card(index, streak: Card.masteryThreshold, seenAt: seenAt)
  }

  /// Stamped a minute apart in index order, so the created timestamp stands in for the row id the
  /// Android suite orders by.
  private func card(_ index: Int, streak: Int, seenAt: Date?) -> CardSummary {
    CardSummary(
      id: UUID(),
      front: "Front \(index)",
      back: "Back \(index)",
      masteryStreak: streak,
      lastSeenAt: seenAt,
      createdAt: start.addingTimeInterval(TimeInterval(index) * 60))
  }

  private func minutesIn(_ minutes: Int) -> Date {
    start.addingTimeInterval(TimeInterval(minutes) * 60)
  }

  private func fronts(_ session: [CardSummary]) -> [String] {
    session.map(\.front)
  }

  /// The Cards in the Mastered slots — every fifth position, counted from one.
  private func everyFifth(_ session: [CardSummary]) -> [String] {
    fronts(session.enumerated().filter { ($0.offset + 1) % 5 == 0 }.map(\.element))
  }
}
