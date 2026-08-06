/// The user's verdict on a Card during Review.
///
/// Two values and no third: there is no "hard", no "easy", and nothing to tune — a Card either
/// came back or it did not, and that is the whole input to the learning model. See ADR 0001.
enum Grade: Sendable {
  /// The Card came back. Lifts its Mastery streak by one.
  case knewIt

  /// It did not. Returns the Card to a Mastery streak of zero, Mastered or not.
  case again
}
