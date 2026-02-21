//
//  EnterKeyHandler.swift
//  GoProConfigurator
//
//  Created by Kevin Matzen on 3/9/25.
//


import UIKit

class EnterKeyHandler: UIView {
    /// A closure that gets called when the Enter key is pressed.
    public var enterKeyAction: (() -> Void)? = nil

    /// Flag to temporarily disable the key handler
    public var isEnabled: Bool = true

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    /// Configures the view to be nearly invisible.
    private func setupView() {
        // Use a transparent view (do not set isHidden to true because hidden views cannot become first responder)
        self.backgroundColor = .clear
        self.alpha = 0.01
    }

    // MARK: - UIResponder Overrides

    /// This view can become first responder so it can intercept key commands.
    override var canBecomeFirstResponder: Bool {
        return isEnabled
    }

    /// Define the key command for the Enter key (represented by "\r").
    override var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(
                input: "\r",
                modifierFlags: [],
                action: #selector(enterKeyPressed),
                discoverabilityTitle: "Enter Key"
            )
        ]
    }

    /// Called when the Enter key is pressed.
    @objc private func enterKeyPressed() {
        enterKeyAction?()
    }

    // MARK: - Managing First Responder

    /// When added to a window, automatically become the first responder (if enabled).
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if isEnabled {
            self.becomeFirstResponder()
        }
    }

    /// Method to enable/disable the handler and manage first responder status
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            self.becomeFirstResponder()
        } else {
            self.resignFirstResponder()
        }
    }
}
