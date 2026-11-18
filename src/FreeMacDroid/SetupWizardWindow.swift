import AppKit

@MainActor
final class SetupWizardWindow: NSWindowController {
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let registerButton = NSButton(title: "Register Extensions", target: nil, action: nil)
    private let openSettingsButton = NSButton(title: "Open File System Extensions Settings", target: nil, action: nil)
    private let copyBrewButton = NSButton(title: "Copy: brew install --cask macfuse", target: nil, action: nil)
    private let mountNowButton = NSButton(title: "Mount Phone Now", target: nil, action: nil)

    var onRequestMount: (() -> Void)?

    convenience init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 390),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "FreeMacDroid — Setup & Diagnostics"
        win.center()
        self.init(window: win)
        buildUI()
        refresh()
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 22, bottom: 20, right: 22)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let heading = NSTextField(labelWithString: "One-Time macOS Setup (No USB Debugging Required)")
        heading.font = NSFont.boldSystemFont(ofSize: 15)

        statusLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        statusLabel.isSelectable = true

        let note = NSTextField(wrappingLabelWithString:
            "Important macOS 26/27 tip: When turning ON macFUSE and macFUSE (local), open Login Items & Extensions → look under By Category (NOT By App) → click (i) next to File System Extensions."
        )
        note.font = NSFont.systemFont(ofSize: 11.5)
        note.textColor = .secondaryLabelColor

        let phoneTip = NSTextField(wrappingLabelWithString:
            "On your Android phone: unlock the screen, tap the USB notification, and pick File transfer / MTP (Transferring files). Keep USB debugging OFF."
        )
        phoneTip.font = NSFont.systemFont(ofSize: 11.5)
        phoneTip.textColor = .secondaryLabelColor

        copyBrewButton.target = self
        copyBrewButton.action = #selector(copyBrewCommand)

        registerButton.target = self
        registerButton.action = #selector(registerExtensions)

        openSettingsButton.target = self
        openSettingsButton.action = #selector(openSettings)

        let refreshButton = NSButton(title: "Refresh Check", target: self, action: #selector(refresh))

        mountNowButton.bezelStyle = .rounded
        mountNowButton.keyEquivalent = "\r"
        mountNowButton.target = self
        mountNowButton.action = #selector(mountNow)

        let row1 = NSStackView(views: [copyBrewButton, registerButton])
        row1.spacing = 10
        let row2 = NSStackView(views: [openSettingsButton, refreshButton, mountNowButton])
        row2.spacing = 10

        stack.addArrangedSubview(heading)
        stack.addArrangedSubview(statusLabel)
        stack.addArrangedSubview(note)
        stack.addArrangedSubview(phoneTip)
        stack.addArrangedSubview(row1)
        stack.addArrangedSubview(row2)

        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor)
        ])
    }

    @objc func refresh() {
        let check = MTPService.shared.checkEnvironment()
        let lines = [
            "\(check.macFUSEInstalled ? "✅" : "❌") macFUSE 5.5+ installed (/Library/Filesystems/macfuse.fs)",
            "\(check.libfuse3Installed ? "✅" : "❌") libfuse3 runtime available (/usr/local/lib/libfuse3.4.dylib)",
            "\(check.extensionsRegistered ? "✅" : "❌") FSKit extensions registered (macfuse & macfuse-local)",
            "\(check.isMounted ? "✅ Mounted" : "ℹ️ Not mounted") at \(check.mountPoint)"
        ]
        statusLabel.stringValue = lines.joined(separator: "\n")
        copyBrewButton.isHidden = check.macFUSEInstalled
        registerButton.isEnabled = check.macFUSEInstalled
        mountNowButton.isEnabled = check.macFUSEInstalled && check.libfuse3Installed
    }

    @objc private func copyBrewCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("brew install --cask macfuse", forType: .string)
        let alert = NSAlert()
        alert.messageText = "Command Copied"
        alert.informativeText = "Paste `brew install --cask macfuse` into Terminal, enter your macOS password when prompted, then click Refresh Check."
        alert.runModal()
    }

    @objc private func registerExtensions() {
        let res = MTPService.shared.registerFSKitExtensions()
        refresh()
        if !res.ok {
            let alert = NSAlert()
            alert.messageText = "Extension Registration"
            alert.informativeText = res.output
            alert.runModal()
        }
    }

    @objc private func openSettings() {
        MTPService.shared.openFileSystemExtensionsSettings()
    }

    @objc private func mountNow() {
        onRequestMount?()
    }
}
