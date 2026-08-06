import SwiftUI

/// One Deck, its Cards, and the ways to change them.
///
/// Two types for the reason `DecksScreen` gives: this one owns the model and does nothing else,
/// and `DeckDetailView` draws a `DeckDetailState` and calls back, so every state — the empty
/// Deck, a filter matching nothing, the broken store — is previewable without a store.
///
/// Starting a Session is presented from here rather than pushed: Review is a modal task with its
/// own exit, and this screen is where it is dismissed back to.
struct DeckDetailScreen: View {
  /// Built when the screen is first pushed and kept for as long as it is on the stack. The
  /// autoclosure is what stops a re-evaluated navigation destination from rebuilding it: `State`
  /// keeps the first value it is given.
  @State private var model: DeckDetailModel

  /// Builds the Session's model for this Deck. A closure rather than the repository itself, so
  /// this screen still names no concrete repository — the composition root does the assembling.
  private let makeSessionModel: () -> SessionModel

  @State private var isReviewing = false
  @Environment(\.dismiss) private var dismiss

  init(
    model: @autoclosure () -> DeckDetailModel,
    makeSessionModel: @escaping () -> SessionModel
  ) {
    _model = State(wrappedValue: model())
    self.makeSessionModel = makeSessionModel
  }

  var body: some View {
    DeckDetailView(
      deckName: model.deckName,
      state: model.state,
      filter: model.filter,
      onFilterChange: { model.show($0) },
      onAddCard: { model.addCard(front: $0, back: $1) },
      onEditCard: { model.updateCard($0, front: $1, back: $2) },
      onDeleteCard: { model.deleteCard($0) },
      onRenameDeck: { model.renameDeck(to: $0) },
      onDeleteDeck: { model.deleteDeck() },
      onStartSession: { isReviewing = true }
    )
    // A full-screen cover, not a push: the tab bar has no business being in a Session, and the
    // Card gets the whole screen. Re-reading on dismissal is what shows the mastery the sitting
    // just earned — every Grade in it moved a streak this screen counts.
    .fullScreenCover(isPresented: $isReviewing, onDismiss: { model.load() }) {
      SessionScreen(model: makeSessionModel())
    }
    // On appear rather than once, so a Deck renamed or emptied elsewhere is picked up on the way
    // back to this screen.
    .onAppear { model.load() }
    // A Deck that is gone — deleted here, or from the list behind this screen — leaves nothing to
    // draw. Leaving is the screen's only sensible response, and it is the model's state that says
    // so, not the button that was tapped: both routes end in the same place.
    .onChange(of: model.state == .gone) { _, isGone in
      if isGone { dismiss() }
    }
  }
}

/// The Deck detail screen's drawing, and nothing else.
///
/// It holds what belongs to the screen rather than to the app — which sheet or prompt is up, and
/// what has been typed into it — and no state that outlives the screen.
struct DeckDetailView: View {
  let deckName: String
  let state: DeckDetailState
  let filter: CardFilter
  let onFilterChange: (CardFilter) -> Void
  let onAddCard: (String, String) -> Void
  let onEditCard: (CardSummary, String, String) -> Void
  let onDeleteCard: (CardSummary) -> Void
  let onRenameDeck: (String) -> Void
  let onDeleteDeck: () -> Void
  let onStartSession: () -> Void

  /// What the Card editor is doing when it is up: writing a new Card, or fixing one that exists.
  /// One sheet for both, because the fields and the rule about them are the same.
  private enum CardEditing: Identifiable {
    case new
    case existing(CardSummary)

    var id: String {
      switch self {
      case .new: "new"
      case .existing(let card): card.id.uuidString
      }
    }
  }

  @State private var editing: CardEditing?
  @State private var cardBeingDeleted: CardSummary?
  @State private var isRenamingDeck = false
  @State private var isDeletingDeck = false
  @State private var enteredDeckName = ""

  var body: some View {
    content
      .navigationTitle(deckName)
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button("Add Card", systemImage: "plus") { editing = .new }
            .disabled(state == .failed || state == .gone)
        }
        ToolbarItem(placement: .topBarTrailing) {
          deckMenu
        }
      }
      .sheet(item: $editing) { editing in
        switch editing {
        case .new:
          CardEditorSheet(title: "New Card", front: "", back: "", confirmTitle: "Add") {
            front, back in
            onAddCard(front, back)
          }
        case .existing(let card):
          CardEditorSheet(
            title: "Edit Card", front: card.front, back: card.back, confirmTitle: "Save"
          ) { front, back in
            onEditCard(card, front, back)
          }
        }
      }
      // The Deck's own rename prompt, matching the Deck list's word for word — the same action
      // reached from a second place should not be a second experience.
      .alert("Rename Deck", isPresented: $isRenamingDeck) {
        TextField("Name", text: $enteredDeckName)
        Button("Cancel", role: .cancel) {}
        Button("Rename") { onRenameDeck(enteredDeckName) }
      }
      .confirmationDialog(
        "Delete Card?", isPresented: isDeletingCard, presenting: cardBeingDeleted
      ) { card in
        Button("Delete", role: .destructive) { onDeleteCard(card) }
        Button("Cancel", role: .cancel) {}
      } message: { card in
        Text("“\(card.front)” will be deleted. This cannot be undone.")
      }
      // Deleting a Deck takes every Card in it. There is no undo anywhere in the app, so this
      // confirmation is the only thing between a mis-tap and losing the lot — and it names what
      // is going, so the question is answerable without dismissing it.
      .confirmationDialog("Delete Deck?", isPresented: $isDeletingDeck) {
        Button("Delete", role: .destructive) { onDeleteDeck() }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("“\(deckName)” and its Cards will be deleted. This cannot be undone.")
      }
  }

  @ViewBuilder
  private var content: some View {
    switch state {
    case .loading, .gone:
      // The read is synchronous and local, so loading is a frame rather than a wait — a spinner
      // here would read as a flicker. `gone` draws nothing for a different reason: the screen is
      // on its way out, and its last frame should not be an error about the Deck it just deleted.
      Color.clear

    case .empty:
      ContentUnavailableView {
        Label("No Cards yet", systemImage: "rectangle.stack.badge.plus")
      } description: {
        Text(
          "A Card is one idea: a Front that prompts you, and a Back that answers it in a plain "
            + "sentence."
        )
      } actions: {
        Button("Add the first Card") { editing = .new }
          .buttonStyle(.borderedProminent)
      }

    case .cards(let contents):
      List {
        Section {
          summaryAndFilter(contents)
        }
        .listRowBackground(Color.clear)

        Section {
          if contents.cards.isEmpty {
            // A filter matching nothing is not an empty Deck, and must not offer to add the
            // first Card — there are Cards, just not these.
            Text(emptyFilterMessage)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          } else {
            ForEach(contents.cards) { card in
              CardRow(card: card)
                .swipeActions(edge: .trailing) {
                  Button("Delete", systemImage: "trash", role: .destructive) {
                    cardBeingDeleted = card
                  }
                  Button("Edit", systemImage: "pencil") { editing = .existing(card) }
                }
            }
          }
        }
      }

    case .failed:
      ContentUnavailableView(
        "This Deck could not be opened",
        systemImage: "exclamationmark.triangle",
        description: Text("Something went wrong reading it. Reopening the app may fix it.")
      )
    }
  }

  /// The mastery summary and the filter, above the Cards and scrolling with them rather than
  /// pinned: they are content, and content passes under the glass toolbar.
  private func summaryAndFilter(_ contents: DeckContents) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      // Near-monochrome, per the visual language: the figure carries the meaning, not a hue.
      Text("\(contents.masteredCount) of \(contents.cardCount) Mastered")
        .font(.headline)
        .accessibilityLabel(
          "\(contents.masteredCount) of \(contents.cardCount) Cards Mastered")

      Picker(
        "Show",
        selection: Binding(get: { filter }, set: { onFilterChange($0) })
      ) {
        ForEach(CardFilter.allCases) { filter in
          Text(filter.title).tag(filter)
        }
      }
      .pickerStyle(.segmented)

      // Studying is what the Deck is for, so it is the one prominent action on the screen — and
      // it sits above the Cards rather than in the toolbar, where it would compete with adding
      // one. It draws from the whole Deck whatever the filter is showing.
      Button("Start Session", systemImage: "play.fill") { onStartSession() }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
    }
    .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
  }

  /// Rename and delete live here, in the Deck's own overflow menu, and **only** here — they have
  /// moved off the Deck list rather than gaining a second home. The Android spec left this menu
  /// as an open question; the iOS spec resolves it.
  private var deckMenu: some View {
    Menu {
      Button("Rename Deck", systemImage: "pencil") {
        enteredDeckName = deckName
        isRenamingDeck = true
      }
      Button("Delete Deck", systemImage: "trash", role: .destructive) { isDeletingDeck = true }
    } label: {
      Label("Deck options", systemImage: "ellipsis")
    }
  }

  private var emptyFilterMessage: String {
    switch filter {
    case .all: "No Cards."
    case .learning: "Every Card in this Deck is Mastered."
    case .mastered: "No Cards are Mastered yet. Keep studying and they will show up here."
    }
  }

  private var isDeletingCard: Binding<Bool> {
    Binding(get: { cardBeingDeleted != nil }, set: { if !$0 { cardBeingDeleted = nil } })
  }
}

/// One Card in the list. Content layer: a standard row with no material of its own.
///
/// Mastered is shown as a symbol rather than a colour — the one place colour does real work in
/// this app is the Grade hint mid-swipe.
private struct CardRow: View {
  let card: CardSummary

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(card.front)
          .font(.body)
        Text(card.back)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if card.isMastered {
        Image(systemName: "checkmark.seal.fill")
          .foregroundStyle(.secondary)
          .accessibilityLabel("Mastered")
      }
    }
  }
}

private func previewCard(
  _ front: String, _ back: String, masteryStreak: Int = 0
) -> CardSummary {
  CardSummary(
    id: UUID(), front: front, back: back, masteryStreak: masteryStreak, lastSeenAt: nil,
    createdAt: .now)
}

private let previewCards = [
  previewCard("hablar", "to speak", masteryStreak: 3),
  previewCard("comer", "to eat", masteryStreak: 1),
  previewCard("vivir", "to live"),
]

#Preview("Deck detail") {
  NavigationStack {
    DeckDetailView(
      deckName: "Spanish verbs",
      state: .cards(DeckContents(cards: previewCards, masteredCount: 1, cardCount: 3)),
      filter: .all,
      onFilterChange: { _ in }, onAddCard: { _, _ in }, onEditCard: { _, _, _ in },
      onDeleteCard: { _ in }, onRenameDeck: { _ in }, onDeleteDeck: {},
      onStartSession: {}
    )
  }
}

#Preview("Filter matching nothing") {
  NavigationStack {
    DeckDetailView(
      deckName: "Spanish verbs",
      state: .cards(DeckContents(cards: [], masteredCount: 0, cardCount: 3)),
      filter: .mastered,
      onFilterChange: { _ in }, onAddCard: { _, _ in }, onEditCard: { _, _, _ in },
      onDeleteCard: { _ in }, onRenameDeck: { _ in }, onDeleteDeck: {},
      onStartSession: {}
    )
  }
}

#Preview("Empty Deck") {
  NavigationStack {
    DeckDetailView(
      deckName: "Spanish verbs", state: .empty, filter: .all,
      onFilterChange: { _ in }, onAddCard: { _, _ in }, onEditCard: { _, _, _ in },
      onDeleteCard: { _ in }, onRenameDeck: { _ in }, onDeleteDeck: {},
      onStartSession: {}
    )
  }
}

#Preview("Store unreadable") {
  NavigationStack {
    DeckDetailView(
      deckName: "Spanish verbs", state: .failed, filter: .all,
      onFilterChange: { _ in }, onAddCard: { _, _ in }, onEditCard: { _, _, _ in },
      onDeleteCard: { _ in }, onRenameDeck: { _ in }, onDeleteDeck: {},
      onStartSession: {}
    )
  }
}
