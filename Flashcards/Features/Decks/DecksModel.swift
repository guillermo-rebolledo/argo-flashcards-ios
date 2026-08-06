import Foundation
import Observation

/// Everything the Decks screen can be, as one value.
///
/// A single enum rather than a set of independent flags, because the states are genuinely
/// exclusive and a `isLoading`/`decks`/`error` triple would admit combinations the screen has no
/// drawing for. `empty` is a state of its own rather than `decks([])` so the first-launch screen
/// is a case the compiler makes the view handle, not a branch someone remembers to write.
enum DecksState: Equatable {
  /// Before the first read returns. Not a spinner in practice — the read is synchronous and local
  /// — but the state the model starts in, and the state a view must be able to draw.
  case loading

  /// There are no Decks. The screen shows the first-launch state.
  case empty

  /// At least one Deck, newest first.
  case decks([DeckSummary])

  /// The store could not be read. Distinct from `empty` on purpose: telling someone with a
  /// hundred Decks that they have none and offering to create their first is worse than telling
  /// them something is wrong.
  case failed

  /// The Decks being shown, or `nil` when the screen is not showing any.
  var decks: [DeckSummary]? {
    if case .decks(let decks) = self { return decks }
    return nil
  }
}

/// The Decks screen's model: the only place the screen's rules live.
///
/// Each action does its work and then re-reads, so the state the view draws is always what the
/// store would return — there is no separately maintained copy of the list to fall out of step
/// with the store. Re-reading is affordable because the whole list is a handful of rows; when it
/// stops being, that is a change here and not in the view.
@MainActor
@Observable
final class DecksModel {
  private(set) var state: DecksState = .loading

  private let repository: any DeckRepository

  init(repository: any DeckRepository) {
    self.repository = repository
  }

  /// Reads the Decks and publishes them. Safe to call again — the screen calls it on appear.
  func load() {
    do {
      let decks = try repository.decks()
      state = decks.isEmpty ? .empty : .decks(decks)
    } catch {
      state = .failed
    }
  }

  /// Creates an empty Deck. A name that is blank once trimmed is not a name, and the action does
  /// nothing rather than making a Deck called "". This is the only place that rule lives, so a
  /// screen cannot be the thing enforcing it.
  func createDeck(named name: String) {
    let name = name.trimmed
    guard !name.isEmpty else { return }

    perform { try repository.createDeck(named: name) }
  }

  /// Renames a Deck. Blank is ignored, for the reason `createDeck(named:)` gives.
  func rename(_ deck: DeckSummary, to name: String) {
    let name = name.trimmed
    guard !name.isEmpty, name != deck.name else { return }

    perform { try repository.rename(deckWithID: deck.id, to: name) }
  }

  /// Deletes a Deck and its Cards. The confirmation this is behind lives in the view; there is
  /// nothing to undo afterwards, which is the spec's choice and the reason for the confirmation.
  func delete(_ deck: DeckSummary) {
    perform { try repository.delete(deckWithID: deck.id) }
  }

  /// Runs a write, then re-reads. A write that throws leaves the screen reporting a broken store
  /// rather than silently showing a list the write did not land in.
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
  /// Trimming is a rule about names, applied in one place so the screen and the store cannot
  /// disagree about whether `" Kanji "` and `"Kanji"` are the same name.
  fileprivate var trimmed: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
