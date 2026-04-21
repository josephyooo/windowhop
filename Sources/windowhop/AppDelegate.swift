import AppKit
import SwiftUI
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var panel: OverlayPanel?
    private var model: OverlayModel?
    private var capturedWindow: AXUIElement?
    private var statusItem: NSStatusItem?
    private let welcome = WelcomeWindowController()

    private lazy var boopSound: NSSound? = NSSound(named: NSSound.Name("Tink"))

    func applicationDidFinishLaunching(_ notification: Notification) {
        welcome.onGranted = { [weak self] in self?.refreshStatusItemIcon() }
        setupStatusItem()
        // nudgeTCCAndCheck registers us in the Accessibility list on first launch
        // and also returns the current trusted state — one call, two jobs.
        if !WindowMover.nudgeTCCAndCheck() {
            welcome.show()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "windowhop" {
            showOverlay()
        }
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
        refreshStatusItemIcon()
    }

    private func refreshStatusItemIcon() {
        guard let button = statusItem?.button else { return }
        let trusted = WindowMover.ensureTrusted(prompt: false)
        if trusted {
            let img = WindowHopIcon.makeNSImage(size: 18, style: .template)
            button.image = img
            button.toolTip = "WindowHop"
        } else {
            let desc = "WindowHop — Accessibility permission needed"
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: desc)
            button.toolTip = desc
        }
    }

    // MARK: - NSMenuDelegate

    /// Rebuilds the menu every time it opens so it always reflects current
    /// permission state without needing a background poller.
    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshStatusItemIcon()
        menu.removeAllItems()

        let trusted = WindowMover.ensureTrusted(prompt: false)
        if trusted {
            let show = NSMenuItem(title: "Show Overlay", action: #selector(showOverlayAction), keyEquivalent: "")
            show.target = self
            menu.addItem(show)
        } else {
            let grant = NSMenuItem(title: "Grant Accessibility…", action: #selector(showWelcomeAction), keyEquivalent: "")
            grant.target = self
            menu.addItem(grant)
        }
        menu.addItem(NSMenuItem.separator())
        let quit = NSMenuItem(title: "Quit WindowHop", action: #selector(quitAction), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func showOverlayAction() { showOverlay() }
    @objc private func showWelcomeAction() { welcome.show() }
    @objc private func quitAction() { NSApp.terminate(nil) }

    // MARK: - Overlay

    private func showOverlay() {
        // If already visible, just refresh state.
        dismissOverlay()

        // Hard gate: no Accessibility → no overlay. Show setup UI instead,
        // otherwise the panel appears but nothing the user does will work.
        guard WindowMover.nudgeTCCAndCheck() else {
            playError()
            welcome.show()
            return
        }

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
        if let boop = boopSound {
            boop.stop()       // rewind if still playing from a prior invocation
            boop.play()
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
