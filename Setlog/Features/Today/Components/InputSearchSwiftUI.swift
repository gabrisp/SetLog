import SwiftUI
import UIKit

struct InputSearchSwiftUI: View {
    let onPlusTap: () -> Void
    let onSubmit: (String) -> Void

    @State private var text: String = ""
    @State private var textHeight: CGFloat = 22

    private let minBarHeight: CGFloat = 44
    private let maxTextHeight: CGFloat = 100
    private let buttonSize: CGFloat = 30
    private let verticalPadding: CGFloat = 11

    var body: some View {
        GeometryReader{
            let size = $0.size
            
            GlassEffectContainer{
                HStack(alignment: .bottom, spacing: 8) {
                    Button(action: onPlusTap) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .medium))
                            .aspectRatio(1, contentMode: .fit)
                            .frame(width: buttonSize, height: buttonSize)
                    }
                    .tint(.primary)
                    .frame(height: minBarHeight, alignment: .center)
                    .padding()
                    .buttonBorderShape(.circle)
                    .setlogGlass(in: .circle)

                    Spacer()
                        .frame(width: 8)
                        
                    GrowingTextView(
                        text: $text,
                        textHeight: $textHeight,
                        maxHeight: maxTextHeight,
                        onSubmit: submit
                    )
                    .frame(height: min(textHeight, maxTextHeight))
                    .setlogGlass(in: .circle)
                    .frame(width: size.width - 8 - (16 * 2) - (buttonSize))

                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button(action: submit) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: buttonSize))
                                .aspectRatio(1, contentMode: .fit)
                                .frame(width: buttonSize, height: buttonSize)
                        }
                        .frame(height: minBarHeight, alignment: .center)
                        .padding()
                        .buttonBorderShape(.circle)
                        .setlogGlass(in: .circle)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                    }
                }
                .padding()
                .frame(minHeight: minBarHeight)
                .animation(.spring(duration: 0.2), value: textHeight)
                .animation(.spring(duration: 0.15), value: text.isEmpty)
            }
        }.frame(maxWidth: .infinity)
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSubmit(trimmed)
        text = ""
        textHeight = 22
    }
}

// MARK: - UITextView wrapper that reports its content height

private struct GrowingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var textHeight: CGFloat
    let maxHeight: CGFloat
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = .systemFont(ofSize: 17)
        tv.textColor = .label
        tv.tintColor = .label
        tv.backgroundColor = .clear
        tv.returnKeyType = .send
        tv.autocorrectionType = .yes
        tv.autocapitalizationType = .sentences
        tv.isScrollEnabled = false
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0

        let ph = UILabel()
        ph.text = "Escribe un comando..."
        ph.font = .systemFont(ofSize: 17)
        ph.textColor = .placeholderText
        ph.translatesAutoresizingMaskIntoConstraints = false
        tv.addSubview(ph)
        NSLayoutConstraint.activate([
            ph.leadingAnchor.constraint(equalTo: tv.leadingAnchor),
            ph.topAnchor.constraint(equalTo: tv.topAnchor),
        ])
        context.coordinator.placeholder = ph

        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        if tv.text != text {
            tv.text = text
            context.coordinator.updateHeight(tv)
        }
        context.coordinator.placeholder?.isHidden = !text.isEmpty
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: GrowingTextView
        weak var placeholder: UILabel?

        init(parent: GrowingTextView) { self.parent = parent }

        func textViewDidChange(_ tv: UITextView) {
            parent.text = tv.text
            placeholder?.isHidden = !tv.text.isEmpty
            updateHeight(tv)
        }

        func textView(_ tv: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "\n" { parent.onSubmit(); return false }
            return true
        }

        func updateHeight(_ tv: UITextView) {
            let size = tv.sizeThatFits(CGSize(width: tv.bounds.width, height: .infinity))
            let clamped = min(size.height, parent.maxHeight)
            tv.isScrollEnabled = size.height > parent.maxHeight
            if abs(clamped - parent.textHeight) > 0.5 {
                parent.textHeight = clamped
            }
        }
    }
}
