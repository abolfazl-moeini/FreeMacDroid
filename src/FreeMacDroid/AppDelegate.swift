import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var wizardController: SetupWizardWindow?
    private let usbMonitor = USBMonitor()

    private var isBusy = false
    private let readOnlyKey = "FreeMacDroid.ReadOnly"
    private let autoMountKey = "FreeMacDroid.AutoMount"

    private var readOnlyMode: Bool {
        get { UserDefaults.standard.bool(forKey: readOnlyKey) }
        set { UserDefaults.standard.set(newValue, forKey: readOnlyKey) }
    }

    private var autoMountMode: Bool {
        get { UserDefaults.standard.bool(forKey: autoMountKey) }
        set { UserDefaults.standard.set(newValue, forKey: autoMountKey) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        usbMonitor.onNonAppleUSBConnected = { [weak self] in
            Task { @MainActor in
                guard let self, self.autoMountMode, !self.isBusy, !MTPService.shared.isCurrentlyMounted() else { return }
                self.performMount(silentErrors: true)
            }
        }
        usbMonitor.start()

        let check = MTPService.shared.checkEnvironment()
        if !check.macFUSEInstalled || !check.libfuse3Installed || !check.extensionsRegistered {
            openSetupWizard()
        } else {
            performMount(silentErrors: false)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            performMount(silentErrors: false)
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        usbMonitor.stop()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "iphone.and.arrow.forward", accessibilityDescription: "FreeMacDroid")
                ?? NSImage(systemSymbolName: "externaldrive", accessibilityDescription: "FreeMacDroid")
            btn.image?.isTemplate = true
            btn.toolTip = "FreeMacDroid — Mount Android Phone in Finder"
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        populateMenu(menu)
    }

    func menuWillOpen(_ menu: NSMenu) {
        populateMenu(menu)
    }

    private func rebuildMenu() {
        if let menu = statusItem.menu {
            populateMenu(menu)
        }
    }

    private func populateMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let mounted = MTPService.shared.isCurrentlyMounted()
        let hasStaleMount = !mounted && MTPService.shared.hasMountEntry()
        let statusTitle: String
        if isBusy {
            statusTitle = "Connecting to Android..."
        } else if mounted {
            statusTitle = "Mounted at ~/Android"
        } else if hasStaleMount {
            statusTitle = "Stale Mount Detected"
        } else {
            statusTitle = "Android Not Mounted"
        }
        let statusEntry = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusEntry.isEnabled = false
        menu.addItem(statusEntry)
        menu.addItem(.separator())

        let mountItem = NSMenuItem(
            title: mounted ? "Open Android in Finder" : "Mount & Open in Finder",
            action: #selector(mountClicked),
            keyEquivalent: "m"
        )
        mountItem.isEnabled = !isBusy
        menu.addItem(mountItem)

        if mounted || hasStaleMount {
            let ejectTitle = hasStaleMount ? "Clean Up Stale Mount" : "Eject / Unmount Phone"
            let ejectItem = NSMenuItem(title: ejectTitle, action: #selector(unmountClicked), keyEquivalent: "e")
            ejectItem.isEnabled = !isBusy
            menu.addItem(ejectItem)
        }

        menu.addItem(.separator())

        let roItem = NSMenuItem(title: "Read-Only Mode", action: #selector(toggleReadOnly), keyEquivalent: "")
        roItem.state = readOnlyMode ? .on : .off
        menu.addItem(roItem)

        let autoItem = NSMenuItem(title: "Auto-Mount on USB Connect", action: #selector(toggleAutoMount), keyEquivalent: "")
        autoItem.state = autoMountMode ? .on : .off
        menu.addItem(autoItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Setup & Diagnostics...", action: #selector(openSetupWizard), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "View Mount Log", action: #selector(viewLog), keyEquivalent: "l"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit FreeMacDroid", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func mountClicked() {
        performMount(silentErrors: false)
    }

    @objc private func unmountClicked() {
        guard !isBusy else { return }
        isBusy = true
        rebuildMenu()
        MTPService.shared.unmount { [weak self] ok, out in
            Task { @MainActor in
                guard let self else { return }
                self.isBusy = false
                self.rebuildMenu()
                if !ok {
                    self.showAlert(title: "Unmount Issue", message: out, showSetupButton: false)
                }
            }
        }
    }

    @objc private func toggleReadOnly() {
        readOnlyMode.toggle()
        rebuildMenu()
    }

    @objc private func toggleAutoMount() {
        autoMountMode.toggle()
        rebuildMenu()
    }

    @objc private func openSetupWizard() {
        if wizardController == nil {
            let wizard = SetupWizardWindow()
            wizard.onRequestMount = { [weak self] in
                self?.performMount(silentErrors: false)
            }
            wizardController = wizard
        }
        wizardController?.refresh()
        wizardController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func viewLog() {
        let logURL = URL(fileURLWithPath: MTPService.shared.logPath)
        if !FileManager.default.fileExists(atPath: logURL.path) {
            try? "(No mount attempts logged yet)".write(to: logURL, atomically: true, encoding: .utf8)
        }
        NSWorkspace.shared.open(logURL)
    }

    private func performMount(silentErrors: Bool) {
        let check = MTPService.shared.checkEnvironment()
        if !check.macFUSEInstalled || !check.libfuse3Installed {
            if !silentErrors { openSetupWizard() }
            return
        }
        if check.isMounted {
            MTPService.shared.openMountInFinder()
            rebuildMenu()
            return
        }
        guard !isBusy else { return }
        isBusy = true
        rebuildMenu()

        MTPService.shared.mount(readOnly: readOnlyMode, openFinder: true) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isBusy = false
                self.rebuildMenu()
                self.wizardController?.refresh()
                if case .failure(let title, let message, let needsSetup) = result, !silentErrors {
                    self.showAlert(title: title, message: message, showSetupButton: needsSetup)
                }
            }
        }
    }

    private func showAlert(title: String, message: String, showSetupButton: Bool) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        if showSetupButton {
            alert.addButton(withTitle: "Open Setup & Settings")
        }
        let response = alert.runModal()
        if showSetupButton && response == .alertSecondButtonReturn {
            openSetupWizard()
            MTPService.shared.openFileSystemExtensionsSettings()
        }
    }
}
