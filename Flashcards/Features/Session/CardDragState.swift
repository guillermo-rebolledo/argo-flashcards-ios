import SwiftUI

/// What letting go of the Card meant.
enum CardDragOutcome: Equatable {
  /// The finger barely moved: this was a tap, and a tap reveals the Back.
  case tap

  /// The Card was thrown far enough, or fast enough, to Grade it. `flight` names the throw, so the
  /// Grade can be recorded when *this* flight lands and not when a later one does.
  case commit(Grade, flight: Int)

  /// Somewhere in between. The Card goes home and nothing is recorded.
  case springBack
}

/// The Card's drag, as a value: where the finger has taken it, what letting go would mean, and how
/// the Card should be drawn in the meantime.
///
/// **This lives outside the view on purpose.** The thresholds, the velocity rule, and the
/// reduced-motion path are the interesting part of the signature interaction, and a `View` cannot
/// be asked what it would have done with a 40pt flick — this type can, which is what
/// `CardDragStateTests` does.
///
/// The thresholds carry over from the Android implementation unchanged. The motion does not: the
/// commit is a spring driven by the view, and this type only ever names the target it springs to,
/// which is what keeps a Card catchable in mid-flight.
struct CardDragState: Equatable {

  /// Where the Card is in a throw.
  enum Phase: Equatable {
    /// Sitting square on, waiting.
    case idle

    /// Under the finger, `CGFloat` points from where it started.
    case dragging(CGFloat)

    /// Thrown, and on its way out — `from` is where the finger let go, which is where a
    /// cross-fading Card stays. The Grade is not recorded until the flight lands.
    case committing(Grade, flight: Int, from: CGFloat)
  }

  /// Under this, the gesture was a tap and belongs to the reveal.
  static let tapThreshold: CGFloat = 10

  /// Past this, the Card is Graded.
  static let commitThreshold: CGFloat = 90

  /// How much of a flick's travel counts towards the commit threshold — a quarter of a second of it.
  /// This is what makes a fast throw commit from short of `commitThreshold`, and a slow one at the
  /// same distance spring back.
  static let velocityProjection: CGFloat = 0.25

  /// The tilt, in degrees, at the commit threshold. The Card leans into the throw; it does not spin.
  static let maxRotation: Double = 8

  /// Far enough that the Card is off any screen the app runs on before the spring settles.
  static let flightDistance: CGFloat = 600

  /// How far the hint chips ride with a Card at the commit threshold. Small: they are a control
  /// floating over the Card, not a second thing being thrown.
  static let hintTravelDistance: CGFloat = 28

  /// Read from the environment by the view and kept here so the reduced-motion path is exercised by
  /// the same tests as everything else. Reduce Motion takes away the flight and the tilt — it does
  /// not take away the Grade, and it does not take away the haptic, which is not motion.
  var reduceMotion = false

  private(set) var phase: Phase = .idle

  /// Throws counted since this state was made, so `commit` can name the one in the air.
  private var flights = 0

  /// Where the Card should be drawn, horizontally. Under Reduce Motion a committed Card does not
  /// fly and does not slide home either: it stays exactly where the finger left it and fades out,
  /// which is what a cross-fade means.
  var offset: CGFloat {
    switch phase {
    case .idle:
      0
    case .dragging(let translation):
      translation
    case .committing(let grade, _, let releasedAt):
      reduceMotion ? releasedAt : Self.flightDistance * grade.direction
    }
  }

  /// How far the Card is towards a commit, as -1 to 1: left for `Again`, right for `Knew it`. The
  /// tilt and the hints both read off this, so they can never disagree about how far along a drag
  /// is.
  var progress: Double {
    switch phase {
    case .idle:
      0
    case .dragging(let translation):
      Double(max(-1, min(1, translation / Self.commitThreshold)))
    case .committing(let grade, _, _):
      Double(grade.direction)
    }
  }

  /// The tilt that goes with the offset, capped at the commit threshold and zeroed under Reduce
  /// Motion.
  var rotation: Angle {
    reduceMotion ? .zero : .degrees(Self.maxRotation * progress)
  }

  /// How far the hints ride with the Card, in points. They travel a fraction of what the Card does
  /// — enough that they separate out of each other as the throw grows, which is the whole reason
  /// they are in a glass effect container. Reduce Motion pins them, and leaves the fade.
  var hintTravel: CGFloat {
    reduceMotion ? 0 : Self.hintTravelDistance * CGFloat(progress)
  }

  /// One under everything except a cross-fading commit, which is what Reduce Motion gets instead of
  /// the flight.
  var opacity: Double {
    if case .committing = phase, reduceMotion { return 0 }
    return 1
  }

  /// The Grade in the air, or `nil` while nothing has been committed. A Card caught mid-flight has
  /// no Grade again.
  var committedGrade: Grade? {
    if case .committing(let grade, _, _) = phase { return grade }
    return nil
  }

  /// Whether a throw is still on its way out, which is the only time the Card is not under control.
  var isFlying: Bool {
    committedGrade != nil
  }

  /// How plainly a hint should read, as the Card moves towards the Grade it stands for: nothing at
  /// rest, full at the commit threshold, and full for a Grade already committed.
  func hintOpacity(for grade: Grade) -> Double {
    switch phase {
    case .idle:
      return 0
    case .dragging(let translation):
      guard translation * grade.direction > 0 else { return 0 }
      return min(1, Double(abs(translation) / Self.commitThreshold))
    case .committing(let committed, _, _):
      return committed == grade ? 1 : 0
    }
  }

  /// Follows the finger. Called on a Card already in flight, this catches it: the throw is
  /// abandoned, its Grade is never recorded, and the Card is back under control.
  mutating func drag(to translation: CGFloat) {
    phase = .dragging(translation)
  }

  /// Lets go, and says what that meant. The phase moves to match, so the view has only to animate
  /// towards whatever this leaves behind.
  ///
  /// `velocity` is the gesture's horizontal velocity in points per second. It counts only when it
  /// carries the Card further the way it was already going — a finger on its way back is not
  /// committing, however fast it is moving.
  mutating func end(translation: CGFloat, velocity: CGFloat) -> CardDragOutcome {
    guard abs(translation) >= Self.tapThreshold else {
      phase = .idle
      return .tap
    }

    let projected = translation + velocity * Self.velocityProjection
    let carriesOn = projected * translation > 0
    guard carriesOn, abs(projected) >= Self.commitThreshold else {
      phase = .idle
      return .springBack
    }

    let grade: Grade = translation > 0 ? .knewIt : .again
    flights += 1
    phase = .committing(grade, flight: flights, from: translation)
    return .commit(grade, flight: flights)
  }

  /// Whether the named throw is the one still in the air. The commit spring is interruptible, so
  /// the animation's completion asks this before recording anything: a Card that was caught, or one
  /// thrown again since, must not Grade twice.
  func isFlightInTheAir(_ flight: Int) -> Bool {
    if case .committing(_, let inTheAir, _) = phase { return inTheAir == flight }
    return false
  }

  /// Squares the Card up for the next one. Reduce Motion survives it — it belongs to the device,
  /// not to the Card.
  mutating func reset() {
    phase = .idle
  }
}

extension Grade {
  /// Which way the Card travels to mean this Grade: right for `Knew it`, left for `Again`.
  ///
  /// The two Grades are the same distance apart in either direction, and the buttons under the Card
  /// are ordered to match, so the two ways of Grading never disagree about which side is which.
  fileprivate var direction: CGFloat {
    switch self {
    case .knewIt: 1
    case .again: -1
    }
  }
}
