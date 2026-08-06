import SwiftUI

/// One sitting, from the first Card to the results.
///
/// Two types for the reason `DecksScreen` gives: this one owns the model and does nothing else,
/// and `SessionView` draws a `SessionState` and calls back, so Review, the results, an empty Deck
/// and a broken store are all previewable without a store.
///
/// **Presented as a full-screen cover, not pushed.** A Session is a modal task with its own exit:
/// the tab bar has no business being there, and the Card gets the whole screen. Results lives
/// inside the same presentation, so finishing dismisses back to where the Session started.
struct SessionScreen: View {
  /// Built when the cover is presented and kept for as long as it is up, so the Session survives
  /// the view being re-evaluated. The autoclosure is what stops that rebuild — `State` keeps the
  /// first value it is given.
  @State private var model: SessionModel

  @Environment(\.dismiss) private var dismiss

  init(model: @autoclosure () -> SessionModel) {
    _model = State(wrappedValue: model())
  }

  var body: some View {
    SessionView(
      state: model.state,
      onReveal: { model.toggleReveal() },
      onGrade: { model.grade($0) },
      onReviewMisses: { model.reviewMisses() },
      onEnd: { dismiss() }
    )
    // The Cards are drawn here rather than in the initialiser so the screen has published a state
    // before the read happens. Calling it again is a no-op: a Session part-way through must not
    // redraw itself on the way back from a system alert.
    .onAppear { model.start() }
  }
}

/// The Session's drawing, and nothing else. It holds no state at all — every Card, every count,
/// and the reveal itself belong to the sitting, which outlives any one appearance of this view.
struct SessionView: View {
  let state: SessionState
  let onReveal: () -> Void
  let onGrade: (Grade) -> Void
  let onReviewMisses: () -> Void
  let onEnd: () -> Void

  var body: some View {
    NavigationStack {
      content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          // Stopping is always available, and never punished: the Cards already Graded keep what
          // they were given, and nothing is asked of the user on the way out.
          ToolbarItem(placement: .cancellationAction) {
            Button("End Session", systemImage: "xmark") { onEnd() }
          }
          if let reviewing = state.reviewing {
            ToolbarItem(placement: .principal) {
              Text("\(reviewing.position) of \(reviewing.total)")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }
          }
        }
    }
  }

  @ViewBuilder
  private var content: some View {
    switch state {
    case .loading:
      // The read is synchronous and local, so this is a frame rather than a wait — the same
      // reason every other screen in the app draws nothing here.
      Color.clear

    case .reviewing(let reviewing):
      ReviewView(reviewing: reviewing, onReveal: onReveal, onGrade: onGrade)

    case .finished(let results):
      ResultsView(results: results, onReviewMisses: onReviewMisses, onDone: onEnd)

    case .empty:
      ContentUnavailableView {
        Label("Nothing to review", systemImage: "rectangle.stack")
      } description: {
        Text("This Deck has no Cards. Add a few and it will be ready to study.")
      } actions: {
        Button("Close") { onEnd() }
          .buttonStyle(.borderedProminent)
      }

    case .failed:
      ContentUnavailableView {
        Label("This Session could not be run", systemImage: "exclamationmark.triangle")
      } description: {
        Text("Something went wrong reading your Cards. Reopening the app may fix it.")
      } actions: {
        Button("Close") { onEnd() }
          .buttonStyle(.borderedProminent)
      }
    }
  }
}

/// One Card, and the two verdicts on it.
private struct ReviewView: View {
  let reviewing: ReviewingCard
  let onReveal: () -> Void
  let onGrade: (Grade) -> Void

  var body: some View {
    VStack(spacing: 24) {
      // Content, sitting under the glass toolbar rather than pinned to it: how far through the
      // sitting the user is belongs beside the Card, not on the control layer.
      ProgressView(value: reviewing.progress)
        .progressViewStyle(.linear)
        .accessibilityLabel("Session progress")
        .accessibilityValue("Card \(reviewing.position) of \(reviewing.total)")

      Spacer(minLength: 0)

      CardFace(card: reviewing.card, isRevealed: reviewing.isRevealed, onTap: onReveal)

      Spacer(minLength: 0)

      gradeButtons
    }
    .padding(20)
  }

  /// `Again` first and `Knew it` second, matching the left-to-right order the swipe will commit in
  /// when it arrives, so the two ways of Grading never disagree about which side is which.
  private var gradeButtons: some View {
    HStack(spacing: 12) {
      Button("Again") { onGrade(.again) }
        .buttonStyle(.bordered)
      Button("Knew it") { onGrade(.knewIt) }
        .buttonStyle(.borderedProminent)
    }
    .controlSize(.large)
    .frame(maxWidth: .infinity)
  }
}

/// The Card itself: a **solid, high-contrast surface, deliberately not glass.** It carries the most
/// important text in the app, and glass over glass has nothing meaningful to refract.
///
/// **Revealing is not a flip.** The Front stays where it is and the Back springs in beneath a
/// divider, with the Card growing to fit — a flip would hide the prompt the user was just trying to
/// recall, and would later collide with the drag as a second 3D transform on one object.
private struct CardFace: View {
  let card: CardSummary
  let isRevealed: Bool
  let onTap: () -> Void

  /// Motion is the only thing Reduce Motion takes away here. The Back still arrives, and it still
  /// arrives beneath the Front — it simply stops springing.
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(spacing: 16) {
      Text(card.front)
        .font(.title2)
        .fontWeight(.medium)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)

      if isRevealed {
        Divider()
        Text(card.back)
          .font(.title3)
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity)
          .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .padding(28)
    .background(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .fill(Color(.secondarySystemGroupedBackground))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    )
    .animation(
      reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.8), value: isRevealed
    )
    .contentShape(Rectangle())
    .onTapGesture { onTap() }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isButton)
    .accessibilityHint(isRevealed ? "Hides the Back" : "Reveals the Back")
  }
}

/// How the pass went, and the two ways out of it.
private struct ResultsView: View {
  let results: SessionResults
  let onReviewMisses: () -> Void
  let onDone: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 8) {
          // Near-monochrome, per the visual language: the figure carries the meaning, not a hue.
          Text("\(results.knewIt) of \(results.total) remembered")
            .font(.title2)
            .fontWeight(.semibold)
            .accessibilityLabel(
              "\(results.knewIt) of \(results.total) Cards remembered on the first pass")

          // Story 53, said plainly and without a number attached to it: there is no backlog, so
          // there is nothing the user should have done more of.
          Text(
            "That was the whole Session. A short Session is a complete one — nothing is "
              + "waiting for you."
          )
          .font(.subheadline)
          .foregroundStyle(.secondary)
        }

        if !results.misses.isEmpty {
          VStack(alignment: .leading, spacing: 12) {
            Text("Worth another look")
              .font(.headline)

            ForEach(results.misses) { card in
              VStack(alignment: .leading, spacing: 4) {
                Text(card.front)
                  .font(.body)
                Text(card.back)
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(16)
              .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                  .fill(Color(.secondarySystemGroupedBackground)))
            }
          }
        }
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    // The way out sits below the results and stays there however long the Miss list is: finishing
    // must be one tap from wherever the user has read to.
    .safeAreaInset(edge: .bottom) {
      VStack(spacing: 12) {
        if results.misses.isEmpty {
          Button("Done") { onDone() }
            .buttonStyle(.borderedProminent)
        } else {
          Button(reviewMissesTitle) { onReviewMisses() }
            .buttonStyle(.borderedProminent)
          Button("Done") { onDone() }
            .buttonStyle(.bordered)
        }
      }
      .controlSize(.large)
      .padding(20)
    }
  }

  /// The Misses named as the glossary names them, and counted, so the button says what tapping it
  /// will run rather than "try again".
  private var reviewMissesTitle: String {
    results.misses.count == 1
      ? "Review the 1 Miss"
      : "Review the \(results.misses.count) Misses"
  }
}

private func previewCard(_ front: String, _ back: String) -> CardSummary {
  CardSummary(
    id: UUID(), front: front, back: back, masteryStreak: 0, lastSeenAt: nil, createdAt: .now)
}

#Preview("Front only") {
  SessionView(
    state: .reviewing(
      ReviewingCard(
        card: previewCard("hablar", "to speak"), isRevealed: false, position: 3, total: 5)),
    onReveal: {}, onGrade: { _ in }, onReviewMisses: {}, onEnd: {})
}

#Preview("Revealed") {
  SessionView(
    state: .reviewing(
      ReviewingCard(
        card: previewCard("hablar", "to speak"), isRevealed: true, position: 3, total: 5)),
    onReveal: {}, onGrade: { _ in }, onReviewMisses: {}, onEnd: {})
}

#Preview("Results with Misses") {
  SessionView(
    state: .finished(
      SessionResults(
        knewIt: 3, total: 5,
        misses: [previewCard("comer", "to eat"), previewCard("vivir", "to live")])),
    onReveal: {}, onGrade: { _ in }, onReviewMisses: {}, onEnd: {})
}

#Preview("Results with nothing Missed") {
  SessionView(
    state: .finished(SessionResults(knewIt: 5, total: 5, misses: [])),
    onReveal: {}, onGrade: { _ in }, onReviewMisses: {}, onEnd: {})
}

#Preview("Nothing to review") {
  SessionView(
    state: .empty, onReveal: {}, onGrade: { _ in }, onReviewMisses: {}, onEnd: {})
}
