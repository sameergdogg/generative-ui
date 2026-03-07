import SwiftUI

struct PromptInputView: View {
    let isLoading: Bool
    let onSubmit: (String) -> Void

    @State private var text = ""

    var body: some View {
        HStack(spacing: 12) {
            TextField("Ask about your transactions...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .disabled(isLoading)
                .onSubmit { submit() }

            Button(action: submit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canSubmit ? Color.accentColor : Color.secondary)
            }
            .disabled(!canSubmit)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        text = ""
        onSubmit(trimmed)
    }
}
