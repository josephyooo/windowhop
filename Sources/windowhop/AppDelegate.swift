import AppKit
import SwiftUI
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: OverlayPanel?
    private var model: OverlayModel?
    private var capturedWindow: AXUIElement?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        WindowMover.ensureTrusted(prompt: true)
        setupStatusItem()
        // First launch: show the overlay immediately so the user gets feedback.
        // Subsequent triggers come through `application(_:open:)` via the URL scheme.
        showOverlay()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "windowhop" {
            showOverlay()
        }
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "rectangle.3.group",
                accessibilityDescription: "WindowHop"
            )
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Show Overlay", action: #selector(showOverlayAction), keyEquivalent: "")
            .target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit WindowHop", action: #selector(quitAction), keyEquivalent: "q")
            .target = self
        item.menu = menu
        statusItem = item
    }

    @objc private func showOverlayAction() { showOverlay() }
    @objc private func quitAction() { NSApp.terminate(nil) }

    // MARK: - Overlay

    private func showOverlay() {
        // If already visible, just refresh state.
        dismissOverlay()

        // Capture BEFORE showing the panel — non-activating panel won't become
        // the frontmost app, but the capture has to happen first regardless.
        capturedWindow = WindowMover.captureFocusedWindow()

        let displays = DisplayInfo.all()
        guard !displays.isEmpty else { NSSound.beep(); return }

        let model = OverlayModel(displays: displays)
        self.model = model

        let content = OverlayView(model: model) { [weak self] display in
            self?.commit(display: display)
        }
        let hosting = NSHostingView(rootView: content)
        let size = NSSize(width: 560, height: 340)
        hosting.frame = NSRect(origin: .zero, size: size)

        let panel = OverlayPanel(contentSize: size)
        panel.contentView = hosting
        panel.onArrow = { [weak self] dx, dy in self?.model?.moveSelection(dx: dx, dy: dy) }
        panel.onNumber = { [weak self] n in
            guard let self, let model = self.model else { return }
            model.selectByNumber(n)
            if let sel = model.selected { self.commit(display: sel) }
        }
        panel.onCommit = { [weak self] in
            if let sel = self?.model?.selected { self?.commit(display: sel) }
        }
        panel.onCancel = { [weak self] in self?.dismissOverlay() }

        let host = NSScreen.screenWithMouse() ?? NSScreen.main ?? NSScreen.screens.first!
        let f = host.frame
        panel.setFrameOrigin(NSPoint(
            x: f.origin.x + (f.width - size.width) / 2,
            y: f.origin.y + (f.height - size.height) / 2
        ))

        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    private func commit(display: DisplayInfo) {
        switch WindowMover.attemptMove(capturedWindow, to: display) {
        case .moved:
            break
        case .noWindow, .fullscreen:
            playError()
        }
        dismissOverlay()
    }

    private func playError() {
        if let sound = NSSound(named: NSSound.Name("Funk")) {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    private func dismissOverlay() {
        panel?.onCancel = nil  // prevent resignKey re-entry
        panel?.orderOut(nil)
        panel = nil
        model = nil
        capturedWindow = nil
    }
}

private extension NSScreen {
    static func screenWithMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
    }
}
