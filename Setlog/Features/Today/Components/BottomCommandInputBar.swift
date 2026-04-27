import SwiftUI

// TODO: Replace internals with UIKit UITextView + inputAccessoryView implementation when visual design is finalized.
// External API (text binding, callbacks) must remain stable — TodayView only sees SwiftUI surface.
struct BottomCommandInputBar: View {

    @Binding var text: String
    let isProcessing: Bool
    let onSubmit: () -> Void
    let onPlusTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlusTap) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            TextField("Add exercise, set, or command…", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .submitLabel(.send)
                .onSubmit(onSubmit)

            if isProcessing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button(action: onSubmit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(text.isEmpty ? Color.secondary : Color.accentColor)
                }
                .disabled(text.isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        // TODO: apply setlogGlass(.regular, in: RoundedRectangle(cornerRadius: 20))
    }
}
