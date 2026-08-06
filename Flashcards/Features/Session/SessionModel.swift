import Foundation
import Observation

/// One Card, as Review is showing it.
///
/// `position` is 1-based because it is read as "3 of 5" — the Card the user is on, not the number
/// of Cards behind them.
struct ReviewingCard: Equatable {
  let card: CardSummary

  /// Whether the Back is showing. Revealing is deliberate, and a Card opened by accident can be
  /// closed again and still attempted.
  let isRevealed: Bool

  let position: Int
  let total: Int

  /// How much of the Session is behind the user — the Card in hand is not done yet, so a Session
  /// starts at zero and only reaches one by ending.
  var progress: Double {
    total == 0 ? 0 : Double(position - 1) / Double(total)
  }
}

/// How a pass came out: the first-pass score, and every Card that did not come back.
///
/// The Misses are the Cards **as they came up**, not as the store holds them now — the list reads
/// as what the user just saw rather than as what Grading them has since done to their streaks.
struct SessionResults: Equatable {
  let knewIt: Int
  let total: Int
  let misses: [CardSummary]

  var score: Double {
    total == 0 ? 0 : Double(knewIt) / Double(total)
  }
}

/// Everything Review can be, as one value. A single enum for the reason [DecksState] gives.
enum SessionState: Equatable {
  /// Before the Cards are drawn.
  case loading

  /// There is nothing to review: the Deck has no Cards, or it was deleted before the Session could
  /// start. Either way the screen says so rather than running a Session of nothing.
  case empty

  /// One Card, Front up until it is revealed.
  case reviewing(ReviewingCard)

  /// The pass is over. Results lives inside the same presentation Review does, so this is a state
  /// of the same screen rather than somewhere the user is sent.
  case finished(SessionResults)

  /// The store could not be read, or a Grade could not be written. Distinct from `empty` for the
  /// reason [DecksState] gives, and from finishing because nothing was recorded.
  case failed

  /// The Card being reviewed, or `nil` when the screen is not reviewing one.
  var reviewing: ReviewingCard? {
    if case .reviewing(let reviewing) = self { return reviewing }
    return nil
  }

  /// The results being shown, or `nil` when the pass is not over.
  var results: SessionResults? {
    if case .finished(let results) = self { return results }
    return nil
  }
}

/// One sitting: the Session's rules, and the only place they live.
///
/// **The Cards are drawn once, when the Session starts, and held for as long as it lasts.** A
/// Session the user is part-way through must not reshuffle underneath them because a Grade they
/// just gave changed what the Deck would compose now — which is why this model does not re-read
/// after a write, unlike every other screen model in the app.
@MainActor
@Observable
final class SessionModel {
  private(set) var state: SessionState = .loading

  private let deckID: UUID
  private let cardRepository: any CardRepository
  private let length: Int

  /// The pass in hand: the Cards drawn for it, how far through it the user is, and how it is
  /// going. A pass over the Misses replaces all three, because it is scored on its own.
  private var cards: [CardSummary] = []
  private var position = 0
  private var knewIt = 0
  private var misses: [CardSummary] = []

  init(deckID: UUID, cardRepository: any CardRepository, length: Int = SessionModel.defaultLength) {
    self.deckID = deckID
    self.cardRepository = cardRepository
    self.length = length
  }

  /// How many Cards a Session holds.
  ///
  /// Fixed here for now. The setting that makes it a choice of 3, 5, or 10 arrives with the
  /// Settings ticket, and arrives as an argument to this model rather than as a second constant.
  static let defaultLength = 5

  /// Draws the Session and shows its first Card. **Calling it again does nothing** — the screen
  /// calls it on appear, and a Session that redrew itself on the way back from a system alert
  /// would lose the pass the user was part-way through.
  func start() {
    guard case .loading = state else { return }

    do {
      begin(composeSession(from: try cardRepository.cards(inDeckWithID: deckID), length: length))
    } catch {
      state = .failed
    }
  }

  /// Shows the Back, or puts it away again.
  func toggleReveal() {
    guard let reviewing = state.reviewing else { return }
    state = .reviewing(
      ReviewingCard(
        card: reviewing.card,
        isRevealed: !reviewing.isRevealed,
        position: reviewing.position,
        total: reviewing.total))
  }

  /// Writes the Grade and moves on, ending the pass if that was the last Card.
  ///
  /// The Card is Graded whether or not its Back was revealed: a user who knew it on sight has no
  /// reason to look. A Grade that cannot be written stops the Session rather than being dropped
  /// silently — it is the one thing a Session produces that outlives it.
  func grade(_ grade: Grade) {
    guard let reviewing = state.reviewing else { return }

    do {
      try cardRepository.recordGrade(grade, forCardWithID: reviewing.card.id)
    } catch {
      state = .failed
      return
    }

    switch grade {
    case .knewIt: knewIt += 1
    case .again: misses.append(reviewing.card)
    }

    position += 1
    state =
      position < cards.count
      ? .reviewing(
        ReviewingCard(
          card: cards[position], isRevealed: false, position: position + 1, total: cards.count))
      : .finished(SessionResults(knewIt: knewIt, total: cards.count, misses: misses))
  }

  /// A second pass over the Cards that did not come back, scored on its own.
  ///
  /// Closing the loop while the material is fresh is the point, so nothing is drawn from the Deck
  /// around them — these Cards and no others, in the order they came up.
  func reviewMisses() {
    guard let results = state.results, !results.misses.isEmpty else { return }
    begin(results.misses)
  }

  private func begin(_ session: [CardSummary]) {
    cards = session
    position = 0
    knewIt = 0
    misses = []
    state =
      session.isEmpty
      ? .empty
      : .reviewing(
        ReviewingCard(
          card: session[0], isRevealed: false, position: 1, total: session.count))
  }
}
