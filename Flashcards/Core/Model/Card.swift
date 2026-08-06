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
  /// it and never stored** — see ADR 0003. The derivation and the threshold arrive with the
  /// mastery rule, which is built test-first in its own ticket.
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
