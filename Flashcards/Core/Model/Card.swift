import Foundation
import SwiftData

/// One idea, with a Front and a Back. Never two ideas.
///
/// A Card has exactly two content fields. There is no example, hint, or image field — see the
/// spec's Out of Scope.
@Model
final class Card {
  var id: UUID
  var front: String
  var back: String

  /// The number of consecutive `Knew it` Grades. `Again` resets it to zero.
  ///
  /// This is the only state a Card carries about how well it is known. **Mastered is derived from
  /// it and never stored** — see ADR 0003. Nothing increments this yet; Grading arrives with the
  /// mastery rule, which is built test-first in its own ticket. It exists here so the Deck
  /// detail filter and the mastery summary are computed from a real value rather than stubbed.
  var masteryStreak: Int

  /// When this Card was last shown in a Session. `nil` until it has been seen once.
  var lastSeenAt: Date?
  var createdAt: Date

  var deck: Deck?

  init(
    id: UUID = UUID(),
    front: String,
    back: String,
    masteryStreak: Int = 0,
    lastSeenAt: Date? = nil,
    createdAt: Date,
    deck: Deck? = nil
  ) {
    self.id = id
    self.front = front
    self.back = back
    self.masteryStreak = masteryStreak
    self.lastSeenAt = lastSeenAt
    self.createdAt = createdAt
    self.deck = deck
  }
}

extension Card {
  /// The number of consecutive `Knew it` Grades at which a Card becomes Mastered.
  ///
  /// One constant, here, rather than a number repeated at each place that filters or counts. It
  /// is a product decision and not a tuning knob: moving it re-labels every Card in the store at
  /// once, with no migration and no way to grandfather Cards in. See ADR 0003.
  /// The derivation itself lives on [CardSummary] — the value every reader of a Card actually
  /// holds — and exists only there, so there is one comparison against this constant and not two
  /// to fall out of step with each other. This type carries the number; nothing stores the
  /// answer.
  static let masteryThreshold = 3
}
