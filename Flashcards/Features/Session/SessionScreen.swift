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

/// One Card, and the three ways to put a verdict on it: the two buttons, and the drag.
private struct ReviewView: View {
  let reviewing: ReviewingCard
  let onReveal: () -> Void
  let onGrade: (Grade) -> Void

  /// The signature interaction's whole state, in a type of its own — see `CardDragState`. The view
  /// only animates towards what it says and reports what the finger did.
  @State private var drag = CardDragState()

  /// Bumped on every commit so the haptic fires once per Grade. Spring-back bumps nothing, which is
  /// what stops the feedback from meaning "you moved" rather than "a Grade registered".
  @State private var committedFlights = 0

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(spacing: 24) {
      // Content, sitting under the glass toolbar rather than pinned to it: how far through the
      // sitting the user is belongs beside the Card, not on the control layer.
      ProgressView(value: reviewing.progress)
        .progressViewStyle(.linear)
        .accessibilityLabel("Session progress")
        .accessibilityValue("Card \(reviewing.position) of \(reviewing.total)")

      Spacer(minLength: 0)

      ZStack(alignment: .bottom) {
        CardFace(card: reviewing.card, isRevealed: reviewing.isRevealed, onTap: onReveal)
          .offset(x: drag.offset)
          .rotationEffect(drag.rotation)
          .opacity(drag.opacity)
          .gesture(dragGesture)

        GradeHints(
          againOpacity: drag.hintOpacity(for: .again),
          knewItOpacity: drag.hintOpacity(for: .knewIt),
          travel: drag.hintTravel
        )
        .padding(.bottom, -18)
        // The hints answer the drag; they must never eat it. A view at zero opacity is still hit
        // tested, so without this the chips would be dead zones over the Card they float on.
        .allowsHitTesting(false)
      }

      Spacer(minLength: 0)

      gradeButtons
    }
    .padding(20)
    // Read on every pass rather than at commit time: the setting can change while a Session is up.
    .onChange(of: reduceMotion, initial: true) { drag.reduceMotion = reduceMotion }
    // The Card that flew away is the same view as the one that replaces it, so the next Card is
    // squared up without animation — it arrives face down and level, never sliding in from the
    // last one's exit.
    .onChange(of: reviewing.card.id) { drag.reset() }
    // Haptics are not motion, so this fires under Reduce Motion too. `.impact` rather than a
    // notification: a Grade is a thing the user did, not news the app is breaking to them.
    .sensoryFeedback(.impact(flexibility: .soft), trigger: committedFlights)
  }

  /// The drag itself. `minimumDistance: 0` so the gesture sees the touch from the first point,
  /// which is what lets a movement under the tap threshold be reported as a tap here rather than
  /// being raced against a separate tap recogniser the drag would swallow.
  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        // Catching a Card in mid-flight is a retarget of the spring already running, not a jump:
        // animating this one change is what lets it come back from wherever it had got to.
        if drag.isFlying {
          withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
            drag.drag(to: value.translation.width)
          }
        } else {
          drag.drag(to: value.translation.width)
        }
      }
      .onEnded { value in
        // The outcome is decided on a copy, so the one state change the view makes is the one the
        // animation below is wrapped around.
        var released = drag
        switch released.end(translation: value.translation.width, velocity: value.velocity.width) {
        case .tap:
          drag = released
          onReveal()

        case .springBack:
          withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { drag = released }

        case .commit(let grade, let flight):
          committedFlights += 1
          // Nothing is recorded until the flight lands, and only if it is still the flight that
          // started here — a Card caught on the way out was never Graded.
          withAnimation(commitAnimation(released: released, velocity: value.velocity.width)) {
            drag = released
          } completion: {
            if drag.isFlightInTheAir(flight) { onGrade(grade) }
          }
        }
      }
  }

  /// The commit's motion: **a spring, never a duration.**
  ///
  /// An interpolating spring rather than SwiftUI's smooth one because this is the only kind that
  /// takes the finger's velocity — a hard flick leaves faster than a slow push over the threshold —
  /// and because it retargets from wherever it has got to, which is what keeps a Card in mid-flight
  /// catchable. A duration-based commit could do neither, and is the clearest tell of a ported
  /// Android app.
  ///
  /// Reduce Motion is the exception: the Card is not going anywhere, so all that is left to time is
  /// the fade.
  private func commitAnimation(released: CardDragState, velocity: CGFloat) -> Animation {
    guard !reduceMotion else { return .easeOut(duration: 0.2) }
    // `initialVelocity` is measured in animations-worth of travel per second, so the gesture's
    // points per second are divided by the distance this particular throw has left to cover.
    let remaining = max(1, abs(released.offset - drag.offset))
    return .interpolatingSpring(
      mass: 1, stiffness: 130, damping: 24, initialVelocity: min(40, abs(velocity) / remaining))
  }

  /// `Again` first and `Knew it` second, matching the left-to-right order the drag commits in, so
  /// the two ways of Grading never disagree about which side is which.
  private var gradeButtons: some View {
    HStack(spacing: 12) {
      Button(Grade.again.title) { onGrade(.again) }
        .buttonStyle(.bordered)
      Button(Grade.knewIt.title) { onGrade(.knewIt) }
        .buttonStyle(.borderedProminent)
    }
    .controlSize(.large)
    .frame(maxWidth: .infinity)
  }
}

/// What letting go would do, floating over the Card.
///
/// **The one place glass earns its keep.** These are controls hovering over content, which is
/// exactly what the material is for. The two chips sit on top of each other at rest and ride apart
/// with the drag, so inside a `GlassEffectContainer` they genuinely morph and merge as the Card
/// moves — the reason for the container rather than two blurred capsules.
///
/// Colour does semantic work here and nowhere else in the app: `.green` for `Knew it`, `.orange`
/// for `Again` — **never red**. `Again` means "come back to this", not "you got it wrong". It is
/// carried by the text and the symbol, not by a tinted glass: ADR 0006 keeps the material itself
/// neutral so what is behind it still shows through.
private struct GradeHints: View {
  let againOpacity: Double
  let knewItOpacity: Double

  /// How far the pair has ridden with the Card. Negative is towards `Again`.
  let travel: CGFloat

  @Namespace private var glass

  var body: some View {
    GlassEffectContainer(spacing: 20) {
      // Closer together than the container's spacing, the two chips read as one lozenge; the drag
      // pulls them past it and they separate, which is the morph the material is here for.
      HStack(spacing: abs(travel)) {
        hint(.again, systemImage: "arrow.counterclockwise", tint: .orange, opacity: againOpacity)
        hint(.knewIt, systemImage: "checkmark", tint: .green, opacity: knewItOpacity)
      }
      .offset(x: travel)
    }
    // The hints answer a drag, and a drag is not something VoiceOver performs: read out, they would
    // announce themselves over the Card and duplicate the two buttons underneath it.
    .accessibilityHidden(true)
  }

  private func hint(
    _ grade: Grade, systemImage: String, tint: Color, opacity: Double
  ) -> some View {
    Label(grade.title, systemImage: systemImage)
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(tint)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .glassEffect(.regular, in: .capsule)
      .glassEffectID(grade.title, in: glass)
      // Tracking the drag over the commit threshold is the affordance: the hint is at its plainest
      // exactly where letting go would Grade.
      .opacity(opacity)
      .scaleEffect(0.9 + 0.1 * opacity)
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
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isButton)
    .accessibilityHint(isRevealed ? "Hides the Back" : "Reveals the Back")
    // The reveal is not its own tap recogniser: a separate one would race the drag for the same
    // touch, and the drag would win. Review reports a movement under the tap threshold as a tap
    // instead, so the two can never disagree. This is the same reveal, for VoiceOver, which has no
    // drag to make.
    .accessibilityAction { onTap() }
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

#Preview("Store unreadable") {
  SessionView(
    state: .failed, onReveal: {}, onGrade: { _ in }, onReviewMisses: {}, onEnd: {})
}
