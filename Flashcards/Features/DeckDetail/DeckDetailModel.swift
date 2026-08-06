import Foundation
import Observation

/// Which part of a Deck the screen is showing.
///
/// The three the spec names, and no "none" case: the segmented control always has a selection,
/// and `all` is what it starts on.
enum CardFilter: CaseIterable, Identifiable, Sendable {
  /// Every Card in the Deck.
  case all

  /// Cards below the mastery threshold — the default state of a new Card.
  case learning

  /// Cards at or above it.
  case mastered

  var id: Self { self }

  /// The label on the segmented control. Glossary terms, unabbreviated.
  var title: String {
    switch self {
    case .all: "All"
    case .learning: "Learning"
    case .mastered: "Mastered"
    }
  }

  /// Whether this Card belongs in the filtered list.
  ///
  /// Filtering happens here, in Swift, over the Deck's Cards rather than in a fetch predicate:
  /// Mastered is derived from the streak and is not a stored column to query. See ADR 0003.
  func matches(_ card: CardSummary) -> Bool {
    switch self {
    case .all: true
    case .learning: !card.isMastered
    case .mastered: card.isMastered
    }
  }
}

/// A Deck's Cards as the screen draws them: the list the filter selected, and the summary, which
/// counts the whole Deck.
///
/// The two are one value rather than two properties so they cannot be read from different loads —
/// "2 of 3 Mastered" above a list from a moment earlier is exactly the disagreement ADR 0003 is
/// about, one layer up.
struct DeckContents: Equatable {
  /// The Cards matching the current filter, newest first. Empty when the filter matches none of
  /// them — which is a Deck with Cards, not an empty Deck.
  let cards: [CardSummary]

  /// How many of the Deck's Cards are Mastered, filter or no filter.
  let masteredCount: Int

  /// How many Cards the Deck holds, filter or no filter.
  let cardCount: Int
}

/// Everything the Deck detail screen can be, as one value. A single enum for the reason
/// [DecksState] gives.
enum DeckDetailState: Equatable {
  /// Before the first read returns.
  case loading

  /// The Deck has no Cards at all. A screen of its own rather than an empty list, so an empty
  /// Deck is not a dead end.
  case empty

  /// The Deck has Cards. The list may still be empty if the filter matches none of them.
  case cards(DeckContents)

  /// The store could not be read or written. Distinct from `empty` for the reason [DecksState]
  /// gives: telling someone with fifty Cards that their Deck is empty is worse than telling them
  /// something is wrong.
  case failed

  /// The Deck is no longer there — deleted from this screen, or from under it. The screen leaves.
  case gone

  /// The Cards and summary being shown, or `nil` when the screen is not showing any.
  var contents: DeckContents? {
    if case .cards(let contents) = self { return contents }
    return nil
  }
}

/// The Deck detail screen's model: the only place the screen's rules live.
///
/// Each action does its work and then re-reads, for the reason [DecksModel] gives — the state the
/// view draws is always what the store would return, and there is no separately maintained copy
/// of the list to fall out of step with it.
@MainActor
@Observable
final class DeckDetailModel {
  private(set) var state: DeckDetailState = .loading

  /// The Deck's name, seeded from the Deck the screen was opened with and re-read on every load.
  ///
  /// It lives beside the state rather than inside it so the title is right in every state,
  /// including `loading` — a title that appears a frame after the screen does reads as a flicker
  /// on push.
  private(set) var deckName: String

  private(set) var filter: CardFilter = .all

  private let deckID: UUID
  private let deckRepository: any DeckRepository
  private let cardRepository: any CardRepository

  init(
    deck: DeckSummary,
    deckRepository: any DeckRepository,
    cardRepository: any CardRepository
  ) {
    self.deckID = deck.id
    self.deckName = deck.name
    self.deckRepository = deckRepository
    self.cardRepository = cardRepository
  }

  /// Reads the Deck and its Cards and publishes them. Safe to call again — the screen calls it on
  /// appear, which is also how it notices a Deck deleted from the Deck list behind it.
  func load() {
    do {
      guard let deck = try deckRepository.deck(withID: deckID) else {
        state = .gone
        return
      }
      deckName = deck.name

      let cards = try cardRepository.cards(inDeckWithID: deckID)
      state =
        cards.isEmpty
        ? .empty
        : .cards(
          DeckContents(
            cards: cards.filter(filter.matches),
            masteredCount: cards.count(where: \.isMastered),
            cardCount: cards.count))
    } catch {
      state = .failed
    }
  }

  /// Narrows the list to one part of the Deck. The summary above it does not narrow with it.
  func show(_ filter: CardFilter) {
    self.filter = filter
    load()
  }

  /// Adds a Card. A Card is exactly two content fields, so one of them blank once trimmed is not
  /// a Card and the action does nothing — the same rule, in the same place, that `DecksModel`
  /// applies to a Deck's name.
  func addCard(front: String, back: String) {
    let front = front.trimmed
    let back = back.trimmed
    guard !front.isEmpty, !back.isEmpty else { return }

    perform {
      let added = try cardRepository.addCard(toDeckWithID: deckID, front: front, back: back)

      // A new Card is Learning and unseen, so the Mastered filter would hide it the instant it
      // was written — the Card would be saved and the screen would look as though nothing had
      // happened. The filter steps aside rather than the Card disappearing: seeing what has been
      // added so far is the point of adding Cards here.
      if let added, !filter.matches(added) { filter = .all }
    }
  }

  /// Rewrites a Card's Front and Back. Blank is ignored, for the reason `addCard` gives.
  ///
  /// **This cannot touch the Card's Mastery streak** — the repository's write has no access to
  /// it. Fixing a typo does not cost a learner their progress. See ADR 0003.
  func updateCard(_ card: CardSummary, front: String, back: String) {
    let front = front.trimmed
    let back = back.trimmed
    guard !front.isEmpty, !back.isEmpty else { return }
    guard front != card.front || back != card.back else { return }

    perform { try cardRepository.updateCard(withID: card.id, front: front, back: back) }
  }

  /// Deletes a Card. There is no undo anywhere in the app; the confirmation this is behind lives
  /// in the view.
  func deleteCard(_ card: CardSummary) {
    perform { try cardRepository.delete(cardWithID: card.id) }
  }

  /// Renames the Deck. Blank is ignored, for the reason `DecksModel.rename` gives.
  func renameDeck(to name: String) {
    let name = name.trimmed
    guard !name.isEmpty, name != deckName else { return }

    perform { try deckRepository.rename(deckWithID: deckID, to: name) }
  }

  /// Deletes the Deck and, by the model's cascade rule, its Cards. The screen has nothing left to
  /// show afterwards and leaves.
  func deleteDeck() {
    do {
      try deckRepository.delete(deckWithID: deckID)
      state = .gone
    } catch {
      state = .failed
    }
  }

  /// Runs a write, then re-reads. A write that throws leaves the screen reporting a broken store
  /// rather than a list the write did not land in.
  private func perform(_ write: () throws -> Void) {
    do {
      try write()
    } catch {
      state = .failed
      return
    }
    load()
  }
}

extension String {
  /// Trimming is a rule about what a user typed, applied in one place. The same rule
  /// `DecksModel` applies to a Deck's name; both are `fileprivate`, so neither file's copy can be
  /// changed on the assumption that the other's moves with it.
  fileprivate var trimmed: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
