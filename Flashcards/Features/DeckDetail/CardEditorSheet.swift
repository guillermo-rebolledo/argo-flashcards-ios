import SwiftUI

/// Writing a Card, and fixing one. The same two fields either way, with the reminder that a Card
/// holds one idea sitting under them.
///
/// The fields grow with what is typed rather than scrolling sideways in a single line, and both
/// take Dynamic Type — a Back is a sentence, and at an accessibility size a fixed-height field
/// would show three words of it.
struct CardEditorSheet: View {
  let title: String
  let confirmTitle: String
  let onConfirm: (String, String) -> Void

  @State private var front: String
  @State private var back: String
  @Environment(\.dismiss) private var dismiss

  init(
    title: String,
    front: String,
    back: String,
    confirmTitle: String,
    onConfirm: @escaping (String, String) -> Void
  ) {
    self.title = title
    self.confirmTitle = confirmTitle
    self.onConfirm = onConfirm
    _front = State(initialValue: front)
    _back = State(initialValue: back)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Front") {
          TextField("A short term, or a direct question", text: $front, axis: .vertical)
        }
        Section {
          TextField("The answer, in one plain sentence", text: $back, axis: .vertical)
        } header: {
          Text("Back")
        } footer: {
          // Story 19, said once and in the place it is acted on rather than as a tip elsewhere.
          Text("One idea per Card. If it holds two, it is two Cards.")
        }
      }
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(confirmTitle) {
            onConfirm(front, back)
            dismiss()
          }
          // A Card is two content fields, so both are required. Unlike the alerts elsewhere in
          // the app, a sheet's toolbar button honours `disabled`, so the rule can be shown here
          // as well as enforced in the model.
          .disabled(!isComplete)
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  private var isComplete: Bool {
    !front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}
