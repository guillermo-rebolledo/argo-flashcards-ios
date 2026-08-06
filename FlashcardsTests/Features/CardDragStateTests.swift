import SwiftUI
import Testing

@testable import Flashcards

/// The drag, exercised the way a finger exercises it: move, let go, and look at what the gesture
/// decided. Every threshold in the ticket is a case here, which is the reason the state lives in
/// its own type rather than inside the view — a `View` cannot be asked what it would have done.
@Suite("Card drag state")
struct CardDragStateTests {

  /// A drag that never left the Card is a tap, and taps belong to the reveal.
  @Test(
    "A drag under the tap threshold is a tap, whichever way it went",
    arguments: [0, 4, -9.9] as [CGFloat])
  func aShortDragIsATap(translation: CGFloat) {
    var drag = CardDragState()
    drag.drag(to: translation)

    #expect(drag.end(translation: translation, velocity: 0) == .tap)
    #expect(drag.phase == .idle)
  }

  @Test("A drag past the commit threshold to the right Grades `Knew it`")
  func aLongRightDragCommitsKnewIt() {
    var drag = CardDragState()
    drag.drag(to: 120)

    #expect(drag.end(translation: 120, velocity: 0) == .commit(.knewIt, flight: 1))
  }

  @Test("A drag past the commit threshold to the left Grades `Again`")
  func aLongLeftDragCommitsAgain() {
    var drag = CardDragState()
    drag.drag(to: -120)

    #expect(drag.end(translation: -120, velocity: 0) == .commit(.again, flight: 1))
  }

  /// Velocity is part of the commit decision, so a flick that would have carried the Card past the
  /// threshold commits from short of it.
  @Test("A fast flick commits from short of the commit threshold")
  func aFastFlickCommitsEarly() {
    var drag = CardDragState()
    drag.drag(to: 40)

    #expect(drag.end(translation: 40, velocity: 900) == .commit(.knewIt, flight: 1))
  }

  @Test("A slow drag to the same distance springs back")
  func aSlowDragOfTheSameDistanceSpringsBack() {
    var drag = CardDragState()
    drag.drag(to: 40)

    #expect(drag.end(translation: 40, velocity: 50) == .springBack)
    #expect(drag.phase == .idle)
  }

  /// A finger already on its way back is not committing, however fast it is moving.
  @Test("Velocity against the drag does not commit")
  func velocityAgainstTheDragDoesNotCommit() {
    var drag = CardDragState()
    drag.drag(to: 60)

    #expect(drag.end(translation: 60, velocity: -1200) == .springBack)
  }

  /// A flick shorter than the tap threshold is still a tap: the reveal wins over a Grade nobody
  /// meant to give.
  @Test("A flick under the tap threshold is a tap, not a Grade")
  func aFlickUnderTheTapThresholdIsATap() {
    var drag = CardDragState()
    drag.drag(to: 6)

    #expect(drag.end(translation: 6, velocity: 2000) == .tap)
  }

  @Test("Hint opacity tracks the drag over the commit threshold")
  func hintOpacityTracksTheDrag() {
    var drag = CardDragState()

    drag.drag(to: 45)
    #expect(drag.hintOpacity(for: .knewIt) == 0.5)
    #expect(drag.hintOpacity(for: .again) == 0)

    drag.drag(to: 200)
    #expect(drag.hintOpacity(for: .knewIt) == 1)

    drag.drag(to: -45)
    #expect(drag.hintOpacity(for: .again) == 0.5)
    #expect(drag.hintOpacity(for: .knewIt) == 0)
  }

  @Test("The Card follows the finger and rotates with it")
  func theCardFollowsTheFingerAndRotates() {
    var drag = CardDragState()

    drag.drag(to: 45)

    #expect(drag.offset == 45)
    #expect(drag.rotation == .degrees(CardDragState.maxRotation / 2))
    #expect(drag.opacity == 1)
  }

  /// Past the commit threshold the tilt stops growing — the Card leans, it does not spin.
  @Test("Rotation is capped at the commit threshold")
  func rotationIsCapped() {
    var drag = CardDragState()

    drag.drag(to: 400)

    #expect(drag.rotation == .degrees(CardDragState.maxRotation))
  }

  @Test("Springing back leaves the Card where it started with no Grade recorded")
  func springingBackLeavesNothingBehind() {
    var drag = CardDragState()
    drag.drag(to: 40)

    _ = drag.end(translation: 40, velocity: 0)

    #expect(drag.offset == 0)
    #expect(drag.rotation == .zero)
    #expect(drag.committedGrade == nil)
    #expect(drag.hintOpacity(for: .knewIt) == 0)
  }

  @Test("A committing Card flies off the way it was thrown")
  func aCommittingCardFliesOff() {
    var drag = CardDragState()
    drag.drag(to: 120)

    _ = drag.end(translation: 120, velocity: 0)

    #expect(drag.offset == CardDragState.flightDistance)
    #expect(drag.opacity == 1)
    #expect(drag.committedGrade == .knewIt)
    #expect(drag.hintOpacity(for: .knewIt) == 1)
    #expect(drag.hintOpacity(for: .again) == 0)
  }

  /// Reduce Motion takes the motion and nothing else: the Grade still commits, and the haptic that
  /// goes with it is not this type's to suppress.
  ///
  /// A cross-fade holds its position — a Card that slid home while fading would be motion by
  /// another name.
  @Test("Under Reduce Motion the Card cross-fades where it was left, and never rotates")
  func reduceMotionCrossFades() {
    var drag = CardDragState()
    drag.reduceMotion = true

    drag.drag(to: 120)
    #expect(drag.rotation == .zero)
    #expect(drag.offset == 120)
    #expect(drag.hintTravel == 0)

    #expect(drag.end(translation: 120, velocity: 0) == .commit(.knewIt, flight: 1))
    #expect(drag.offset == 120)
    #expect(drag.opacity == 0)
    #expect(drag.rotation == .zero)
  }

  /// The hints ride with the Card so the glass chips separate out of one another as the throw
  /// grows — the merge is the reason they are in a glass effect container at all.
  @Test("The hints ride with the drag, and stop at the commit threshold")
  func theHintsRideWithTheDrag() {
    var drag = CardDragState()

    #expect(drag.hintTravel == 0)

    drag.drag(to: 45)
    #expect(drag.hintTravel == CardDragState.hintTravelDistance / 2)

    drag.drag(to: -300)
    #expect(drag.hintTravel == -CardDragState.hintTravelDistance)
  }

  /// The commit animation is interruptible, so the Grade is only recorded if the Card that was
  /// thrown is still the one in the air when the flight lands.
  @Test("A flight that lands untouched records its Grade")
  func anUntouchedFlightRecordsItsGrade() {
    var drag = CardDragState()
    drag.drag(to: 120)
    guard case .commit(_, let flight) = drag.end(translation: 120, velocity: 0) else {
      Issue.record("Expected a commit")
      return
    }

    #expect(drag.isFlightInTheAir(flight))
  }

  @Test("A Card caught mid-flight drags back and its Grade never lands")
  func aCaughtCardIsNotGraded() {
    var drag = CardDragState()
    drag.drag(to: 120)
    guard case .commit(_, let flight) = drag.end(translation: 120, velocity: 0) else {
      Issue.record("Expected a commit")
      return
    }

    drag.drag(to: 20)

    #expect(drag.isFlightInTheAir(flight) == false)
    #expect(drag.offset == 20)
    #expect(drag.committedGrade == nil)
    #expect(drag.end(translation: 20, velocity: 0) == .springBack)
  }

  /// Each throw is its own flight, so a Grade landing cannot be mistaken for the one before it.
  @Test("Each commit is a flight of its own")
  func eachCommitIsItsOwnFlight() {
    var drag = CardDragState()
    drag.drag(to: 120)
    _ = drag.end(translation: 120, velocity: 0)
    drag.reset()

    drag.drag(to: -120)

    #expect(drag.end(translation: -120, velocity: 0) == .commit(.again, flight: 2))
    #expect(drag.isFlightInTheAir(1) == false)
  }

  @Test("The next Card starts square on, whatever the last one did")
  func resetSquaresTheNextCard() {
    var drag = CardDragState()
    drag.drag(to: 120)
    _ = drag.end(translation: 120, velocity: 0)

    drag.reset()

    #expect(drag.phase == .idle)
    #expect(drag.offset == 0)
    #expect(drag.opacity == 1)
    #expect(drag.rotation == .zero)
    #expect(drag.committedGrade == nil)
  }

  /// Reduce Motion is read from the environment on every pass, so it must survive a reset.
  @Test("Reduce Motion outlives the Card it was read for")
  func reduceMotionSurvivesAReset() {
    var drag = CardDragState()
    drag.reduceMotion = true
    drag.drag(to: 120)

    drag.reset()

    #expect(drag.reduceMotion)
  }
}
