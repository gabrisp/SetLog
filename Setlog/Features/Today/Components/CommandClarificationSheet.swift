import SwiftUI

struct CommandClarificationSheet: View {

    let request: CommandConfirmationRequest
    @Binding var customText: String
    let onSelectChoice: (CommandConfirmationChoice) -> Void
    let onSubmitCustom: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(request.prompt)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Opciones rápidas")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(Array(request.choices.enumerated()), id: \.offset) { _, choice in
                            Button {
                                onSelectChoice(choice)
                            } label: {
                                HStack {
                                    Text(choice.label)
                                        .font(.subheadline)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 8)
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Opción personalizada")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField("Escribe el comando exacto...", text: $customText, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            onSubmitCustom()
                        } label: {
                            Text("Enviar comando")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Aclarar comando")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") {
                        onDismiss()
                    }
                }
            }
        }
    }
}
