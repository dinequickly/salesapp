import UIKit

final class UserIdEntryViewController: UIViewController {
    var onCompletion: (() -> Void)?

    private let stackView = UIStackView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let textField = UITextField()
    private let continueButton = UIButton(type: .system)
    private let errorLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Welcome"
        configureLayout()
        applyExistingUserId()
    }

    private func configureLayout() {
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        titleLabel.text = "Enter Your User ID"
        titleLabel.font = UIFont.preferredFont(forTextStyle: .title1)
        titleLabel.textAlignment = .center

        descriptionLabel.text = "This ID is used to load past conversations and interact with the coaching agent."
        descriptionLabel.font = UIFont.preferredFont(forTextStyle: .body)
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0

        textField.placeholder = "User ID"
        textField.borderStyle = .roundedRect
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.textAlignment = .center
        textField.returnKeyType = .done
        textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)

        continueButton.setTitle("Continue", for: .normal)
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.backgroundColor = .systemBlue
        continueButton.layer.cornerRadius = 12
        continueButton.layer.masksToBounds = true
        continueButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        continueButton.addTarget(self, action: #selector(handleContinue), for: .touchUpInside)

        errorLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        errorLabel.textColor = .systemRed
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(descriptionLabel)
        stackView.addArrangedSubview(textField)
        stackView.addArrangedSubview(continueButton)
        stackView.addArrangedSubview(errorLabel)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func applyExistingUserId() {
        if let current = AppState.shared.userId {
            textField.text = current
        }
        updateContinueAvailability()
    }

    @objc private func textFieldDidChange() {
        errorLabel.isHidden = true
        updateContinueAvailability()
    }

    private func updateContinueAvailability() {
        let hasText = !(textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        continueButton.isEnabled = hasText
        continueButton.alpha = hasText ? 1.0 : 0.5
    }

    @objc private func handleContinue() {
        let trimmed = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showError("Please enter a valid user ID.")
            return
        }

        AppState.shared.setUserId(trimmed)
        AppState.shared.loadCachedConversations()
        onCompletion?()
    }

    private func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
    }
}
