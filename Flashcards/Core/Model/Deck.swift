import Foundation
import SwiftData

/// A named collection of Cards on one topic. The unit a Session is drawn from.
@Model
final class Deck {
  /// Stable identity, independent of SwiftData's persistent identifier.
  var id: UUID
  var name: String
  var createdAt: Date

  /// Deleting a Deck deletes its Cards. A Card has no meaning outside the Deck it belongs to.
  @Relationship(deleteRule: .cascade, inverse: \Card.deck)
  var cards: [Card]

  init(id: UUID = UUID(), name: String, createdAt: Date, cards: [Card] = []) {
    self.id = id
    self.name = name
    self.createdAt = createdAt
    self.cards = cards
  }
}
