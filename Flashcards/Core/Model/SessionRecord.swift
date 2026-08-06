import Foundation
import SwiftData

/// One row per completed Session, written when the sitting ends.
///
/// **Every figure on the Progress screen is computed from this model and nothing else**, so no
/// separate counters exist to drift. Those computations are Swift folds over fetched rows rather
/// than queries — see ADR 0007 for why, and for the rule that they all live in a single type.
///
/// Named `SessionRecord` rather than `Session` because `Session` in the glossary is the sitting
/// itself — the thing the user is doing — and that name belongs to the type that models a Session
/// in progress. This is the log row it leaves behind. `CONTEXT.md` calls the collection of these
/// the **Session log**.
@Model
final class SessionRecord {
  var id: UUID

  /// The Deck the Session was drawn from. Nullable so deleting a Deck does not delete the history
  /// of having studied it — Progress figures survive the Deck they came from.
  var deck: Deck?

  var startedAt: Date
  var endedAt: Date

  /// How many Cards were Graded in the sitting.
  var cardsReviewed: Int

  /// How many of those were Graded `Knew it`.
  var knewItCount: Int

  init(
    id: UUID = UUID(),
    deck: Deck? = nil,
    startedAt: Date,
    endedAt: Date,
    cardsReviewed: Int,
    knewItCount: Int
  ) {
    self.id = id
    self.deck = deck
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.cardsReviewed = cardsReviewed
    self.knewItCount = knewItCount
  }
}
