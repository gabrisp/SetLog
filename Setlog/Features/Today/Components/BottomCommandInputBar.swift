import SwiftUI
import UIKit

struct BottomCommandInputBar: UIViewRepresentable {

    @Binding var text: String
    let isProcessing: Bool
    let onSubmit: () -> Void
    let onPlusTap: () -> Void

    func makeUIView(context: Context) -> CommandInputBarView {
        let view = CommandInputBarView()
        view.onSubmit = onSubmit
        view.onPlusTap = onPlusTap
        view.onTextChange = { text = $0 }
        return view
    }

    func updateUIView(_ uiView: CommandInputBarView, context: Context) {
        uiView.onSubmit = onSubmit
        uiView.onPlusTap = onPlusTap
        uiView.setProcessing(isProcessing)

        if uiView.currentText != text {
            uiView.setText(text)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: CommandInputBarView, context: Context) -> CGSize? {
        let resolvedWidth: CGFloat
        if let width = proposal.width, width > 0 {
            resolvedWidth = width
        } else if uiView.bounds.width > 0 {
            resolvedWidth = uiView.bounds.width
        } else if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            resolvedWidth = scene.screen.bounds.width
        } else {
            resolvedWidth = 390
        }
        return CGSize(width: resolvedWidth, height: 52)
    }
}

final class CommandInputBarView: UIView {

    var onSubmit: (() -> Void)?
    var onPlusTap: (() -> Void)?
    var onTextChange: ((String) -> Void)?

    private(set) var currentText = ""

    private let plusButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.tintColor = .label
        button.backgroundColor = .tertiarySystemFill
        button.layer.cornerRadius = 22
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let inputHost: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.layer.cornerRadius = 22
        view.clipsToBounds = true
        return view
    }()

    private let textField: UITextField = {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = "Escribe un comando..."
        field.font = .systemFont(ofSize: 17)
        field.textColor = .label
        field.tintColor = .label
        field.backgroundColor = .clear
        field.returnKeyType = .send
        field.autocorrectionType = .yes
        field.autocapitalizationType = .sentences
        return field
    }()

    private let sendButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(
            UIImage(
                systemName: "arrow.up.circle.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .regular)
            ),
            for: .normal
        )
        button.tintColor = UIColor(named: "AccentColor") ?? .systemBlue
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setText(_ text: String) {
        currentText = text
        textField.text = text
        updateSendState()
    }

    func setProcessing(_ processing: Bool) {
        textField.isEnabled = !processing
        sendButton.isEnabled = !processing
        plusButton.isEnabled = !processing

        let dimAlpha: CGFloat = processing ? 0.55 : 1.0
        inputHost.alpha = dimAlpha
        plusButton.alpha = dimAlpha

        updateSendState()
    }

    private func setup() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        textField.delegate = self

        addSubview(plusButton)
        addSubview(inputHost)
        inputHost.addSubview(textField)
        inputHost.addSubview(sendButton)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 52),

            plusButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            plusButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            plusButton.widthAnchor.constraint(equalToConstant: 44),
            plusButton.heightAnchor.constraint(equalToConstant: 44),

            inputHost.leadingAnchor.constraint(equalTo: plusButton.trailingAnchor, constant: 10),
            inputHost.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            inputHost.centerYAnchor.constraint(equalTo: centerYAnchor),
            inputHost.heightAnchor.constraint(equalToConstant: 44),

            textField.leadingAnchor.constraint(equalTo: inputHost.leadingAnchor, constant: 14),
            textField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            textField.centerYAnchor.constraint(equalTo: inputHost.centerYAnchor),

            sendButton.trailingAnchor.constraint(equalTo: inputHost.trailingAnchor, constant: -4),
            sendButton.centerYAnchor.constraint(equalTo: inputHost.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 38),
            sendButton.heightAnchor.constraint(equalToConstant: 38),
        ])

        plusButton.addTarget(self, action: #selector(didTapPlus), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(didTapSend), for: .touchUpInside)
        textField.addTarget(self, action: #selector(textDidChange), for: .editingChanged)

        updateSendState()
    }

    private func updateSendState() {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let enabled = !trimmed.isEmpty && textField.isEnabled
        sendButton.isEnabled = enabled
        sendButton.tintColor = enabled ? (UIColor(named: "AccentColor") ?? .systemBlue) : .secondaryLabel
    }

    @objc private func didTapPlus() {
        onPlusTap?()
    }

    @objc private func didTapSend() {
        guard textField.isEnabled else { return }
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSubmit?()
    }

    @objc private func textDidChange() {
        currentText = textField.text ?? ""
        onTextChange?(currentText)
        updateSendState()
    }
}

extension CommandInputBarView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        didTapSend()
        return false
    }
}
