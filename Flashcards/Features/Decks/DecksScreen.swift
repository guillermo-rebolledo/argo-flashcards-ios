import SwiftUI

/// The home tab.
///
/// Two types, deliberately: this one owns the model and does nothing else, and `DecksView` below
/// draws a `DecksState` and calls back. The split is what lets every state — including the empty
/// one and the broken-store one — be previewed and reasoned about without a store, and it is the
/// shape every later screen copies.
///
/// The "Up next" card and navigation into Deck detail arrive with their own tickets.
struct DecksScreen: View {
  /// Owned by the shell and handed in, not created here: the model outlives any one appearance of
  /// this view, and the composition root is the only place that knows how to build one.
  let model: DecksModel

  var body: some View {
    DecksView(
      state: model.state,
      onCreateDeck: { model.createDeck(named: $0) },
      onRename: { model.rename($0, to: $1) },
      onDelete: { model.delete($0) }
    )
    .onAppear { model.load() }
  }
}

/// The Decks screen's drawing, and nothing else.
///
/// It holds the state that belongs to the screen rather than to the app — which prompt is up, what
/// has been typed into the name field so far — and no state that outlives the screen. Every change
/// to a Deck leaves through a closure.
struct DecksView: View {
  let state: DecksState
  let onCreateDeck: (String) -> Void
  let onRename: (DeckSummary, String) -> Void
  let onDelete: (DeckSummary) -> Void

  /// The name being typed, shared by the create and rename prompts — only one of them is ever up.
  @State private var enteredName = ""
  @State private var isNamingNewDeck = false
  @State private var deckBeingRenamed: DeckSummary?
  @State private var deckBeingDeleted: DeckSummary?

  var body: some View {
    content
      .navigationTitle("Decks")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          createMenu
        }
      }
      // Neither confirm button is disabled on a blank name: an alert's action buttons take their
      // role and nothing else, so a `.disabled` here would be quietly ignored and the code would
      // read as if a rule were being enforced that was not. The rule lives in the model, which
      // ignores a blank name, so confirming one closes the prompt and changes nothing.
      .alert("New Deck", isPresented: $isNamingNewDeck) {
        TextField("Name", text: $enteredName)
        Button("Cancel", role: .cancel) {}
        Button("Create") { onCreateDeck(enteredName) }
      } message: {
        Text("What is this Deck about?")
      }
      .alert("Rename Deck", isPresented: isRenaming, presenting: deckBeingRenamed) { deck in
        TextField("Name", text: $enteredName)
        Button("Cancel", role: .cancel) {}
        Button("Rename") { onRename(deck, enteredName) }
      }
      // Deleting is confirmed rather than undoable — there is no undo anywhere in the app, so the
      // confirmation is the only thing standing between a mis-tap and losing a Deck's Cards. The
      // Deck is named in the message so the question is answerable without dismissing it.
      .confirmationDialog(
        "Delete Deck?", isPresented: isDeleting, presenting: deckBeingDeleted
      ) { deck in
        Button("Delete", role: .destructive) { onDelete(deck) }
        Button("Cancel", role: .cancel) {}
      } message: { deck in
        Text("“\(deck.name)” and its Cards will be deleted. This cannot be undone.")
      }
  }

  @ViewBuilder
  private var content: some View {
    switch state {
    case .loading:
      // The read is synchronous and local, so this is a frame rather than a wait. A spinner that
      // appears for one frame reads as a flicker; nothing does not.
      Color.clear

    case .empty:
      ContentUnavailableView {
        Label("No Decks yet", systemImage: "rectangle.on.rectangle")
      } description: {
        // Worded from the glossary's own definition. "Set" and "collection" are on its avoid
        // list for a Deck, so the copy says what a Deck holds rather than renaming it.
        Text(
          "A Deck holds Cards on one topic. Make one, then fill it with Cards — by hand, or "
            + "from something you have been reading."
        )
      } actions: {
        Button("Create an empty Deck") { startNamingNewDeck() }
          .buttonStyle(.borderedProminent)
      }

    case .decks(let decks):
      List {
        ForEach(decks) { deck in
          DeckRow(deck: deck)
            // Rename and delete reach the Deck by swipe here. Deck detail's toolbar carries the
            // same two, which is where the spec puts them; a context menu as well would be a
            // third way to the same pair and is not asked for.
            .swipeActions(edge: .trailing) {
              Button("Delete", systemImage: "trash", role: .destructive) {
                deckBeingDeleted = deck
              }
              Button("Rename", systemImage: "pencil") { startRenaming(deck) }
            }
        }
      }

    case .failed:
      ContentUnavailableView(
        "Your Decks could not be opened",
        systemImage: "exclamationmark.triangle",
        description: Text("Something went wrong reading them. Reopening the app may fix it.")
      )
    }
  }

  /// Creation lives here rather than in a floating action button. A FAB is Material's signature
  /// object, and the three paths it would fan out into are a menu's job on iOS.
  ///
  /// Two of the three are present and disabled: their flows arrive with their own tickets, and
  /// placing them now settles the menu's shape — and the order the user learns — before those
  /// flows land behind them.
  private var createMenu: some View {
    Menu {
      Button("Generate from text or a link", systemImage: "sparkles") {}
        .disabled(true)
      Button("Add Cards by hand", systemImage: "square.and.pencil") {}
        .disabled(true)
      Button("Create an empty Deck", systemImage: "rectangle.stack.badge.plus") {
        startNamingNewDeck()
      }
    } label: {
      Label("New Deck", systemImage: "plus")
    }
  }

  private func startNamingNewDeck() {
    enteredName = ""
    isNamingNewDeck = true
  }

  private func startRenaming(_ deck: DeckSummary) {
    enteredName = deck.name
    deckBeingRenamed = deck
  }

  /// `presenting:` needs a `Bool` binding alongside the value; these derive one from the other so
  /// the two cannot disagree.
  private var isRenaming: Binding<Bool> {
    Binding(get: { deckBeingRenamed != nil }, set: { if !$0 { deckBeingRenamed = nil } })
  }

  private var isDeleting: Binding<Bool> {
    Binding(get: { deckBeingDeleted != nil }, set: { if !$0 { deckBeingDeleted = nil } })
  }
}

/// One Deck in the list. Content layer: a standard row sitting under the glass tab bar, with no
/// material of its own. Card counts and mastery arrive with Deck detail.
private struct DeckRow: View {
  let deck: DeckSummary

  var body: some View {
    Text(deck.name)
      .font(.body)
  }
}

/// Previews cover each state the screen can be in, which is the point of `DecksView` taking a
/// state rather than a store: the empty state and the failure state are one line each here, and
/// would otherwise need a store rigged to produce them.
#Preview("Decks") {
  NavigationStack {
    DecksView(
      state: .decks([
        DeckSummary(id: UUID(), name: "Spanish verbs", createdAt: .now),
        DeckSummary(id: UUID(), name: "Kanji — chapter 3", createdAt: .now),
      ]),
      onCreateDeck: { _ in }, onRename: { _, _ in }, onDelete: { _ in }
    )
  }
}

#Preview("First launch") {
  NavigationStack {
    DecksView(
      state: .empty, onCreateDeck: { _ in }, onRename: { _, _ in }, onDelete: { _ in })
  }
}

#Preview("Store unreadable") {
  NavigationStack {
    DecksView(
      state: .failed, onCreateDeck: { _ in }, onRename: { _, _ in }, onDelete: { _ in })
  }
}
