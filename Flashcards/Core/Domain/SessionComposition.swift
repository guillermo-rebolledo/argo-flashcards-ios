import Foundation

/// Which Cards a Session draws from a Deck, and in what order.
///
/// Most slots go to Learning Cards, weakest first, so the user's attention lands on what they do
/// not know yet. Every fifth slot goes to a Mastered Card, so "Mastered" still means something
/// months later. When a category runs out its slots fall through to the other, so a Deck with
/// nothing Mastered, a Deck with nothing left to learn, and a Deck smaller than the Session all
/// give a full Session of whatever they have.
///
/// The every-fifth rule is **positional rather than probabilistic**: the same Cards always compose
/// the same Session, so there is no random source to inject and nothing to seed in a test.
///
/// A free function rather than a method on something, because it is a rule about a list of Cards
/// and holds no state — the same shape the Android implementation has, which is what lets the two
/// suites be read side by side.
///
/// - Parameters:
///   - cards: Every Card in the Deck, in any order. Composition depends on the set, not on the
///     order it arrived in.
///   - length: How many Cards the Session should hold. A Deck with fewer gives what it has.
/// - Returns: The Cards of the Session, in the order they will be shown.
func composeSession(from cards: [CardSummary], length: Int) -> [CardSummary] {
  guard length > 0 else { return [] }

  var learning = cards.filter { !$0.isMastered }.sorted(by: learningOrder)[...]
  var mastered = cards.filter(\.isMastered).sorted(by: masteredOrder)[...]

  // A slot whose category is exhausted falls through to the other rather than leaving a hole, so
  // a Session is short only when the Deck itself has nothing left to put in it.
  return (1...length).compactMap { slot in
    slot % masteredSlot == 0
      ? mastered.popFirst() ?? learning.popFirst()
      : learning.popFirst() ?? mastered.popFirst()
  }
}

/// Slot five, then ten — the first four of any Session are Learning Cards.
private let masteredSlot = 5

/// Weakest first, then whatever has waited longest.
///
/// A Card that has never been through a Review has waited longest of all, which is why an absent
/// last-seen sorts first. Creation time breaks the last tie, so a Deck of new Cards composes the
/// same Session on every read rather than the order the rows happened to come back in — and the id
/// breaks that one, because two Cards written by the same Generation share a timestamp. Android
/// breaks both ties on the row id, which is assigned in creation order; a `UUID` is not, so the
/// order it stands in for is spelled out here.
private func learningOrder(_ first: CardSummary, _ second: CardSummary) -> Bool {
  if first.masteryStreak != second.masteryStreak {
    return first.masteryStreak < second.masteryStreak
  }
  return waitedLonger(first, second)
}

/// Streaks differ among Mastered Cards but say nothing useful; only the wait matters here.
private func masteredOrder(_ first: CardSummary, _ second: CardSummary) -> Bool {
  waitedLonger(first, second)
}

private func waitedLonger(_ first: CardSummary, _ second: CardSummary) -> Bool {
  switch (first.lastSeenAt, second.lastSeenAt) {
  case (nil, .some): return true
  case (.some, nil): return false
  case (.some(let first), .some(let second)) where first != second: return first < second
  default: break
  }
  if first.createdAt != second.createdAt { return first.createdAt < second.createdAt }
  return first.id.uuidString < second.id.uuidString
}
