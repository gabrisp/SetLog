import SwiftUI

struct SheetHeader: View {

    let title: String
    let onDismiss: (() -> Void)?

    init(title: String, onDismiss: (() -> Void)? = nil) {
        self.title = title
        self.onDismiss = onDismiss
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)

            Spacer()

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}
