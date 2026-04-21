import AppKit
import SwiftUI

@MainActor
final class WelcomeWindowController {
    private var window: NSWindow?
    private var pollTimer: Timer?

    var isVisible: Bool { window?.isVisible == true }

    /// Fired exactly once per show() cycle, when polling detects the grant.
    var onGranted: (() -> Void)?

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let size = NSSize(width: 460, height: 320)
        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "WindowHop"
        w.isReleasedWhenClosed = false
        w.level = .floating
        w.center()

        let view = WelcomeView(
            openSettings: { [weak self] in self?.openAccessibilitySettings() },
            recheck: { [weak self] in self?.checkNow() },
            relaunch: { [weak self] in self?.relaunchApp() }
        )
        w.contentView = NSHostingView(rootView: view)
        self.window = w

        // Silently register the process in the Accessibility list without
        // popping a system dialog — our welcome window IS the dialog.
        WindowMover.nudgeTCCAndCheck()

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        startPolling()
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkNow() }
        }
    }

    /// Polled and called from button actions. Uses nudgeTCCAndCheck so that
    /// if the user has deleted the TCC entry in Settings, it gets re-added
    /// silently on the next tick and the entry reappears in the list.
    private func checkNow() {
        if WindowMover.nudgeTCCAndCheck() {
            dismiss()
            onGranted?()
        }
    }

    private func dismiss() {
        pollTimer?.invalidate()
        pollTimer = nil
        window?.orderOut(nil)
    }

    private func openAccessibilitySettings() {
        // Nudge *right before* opening the pane so the entry is registered
        // (or re-registered after the user deleted it) when Settings reads
        // the Accessibility list.
        WindowMover.nudgeTCCAndCheck()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func relaunchApp() {
        let url = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.terminate(nil)
        }
    }
}

private struct WelcomeView: View {
    let openSettings: () -> Void
    let recheck: () -> Void
    let relaunch: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(.tint)
                .padding(.top, 8)

            Text("WindowHop needs Accessibility")
                .font(.title2).bold()

            Text("To move the focused window between displays, WindowHop needs Accessibility permission.\n\nOpen **Privacy & Security → Accessibility**, enable **WindowHop**, then return here. This window will close automatically once it's granted.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            HStack(spacing: 10) {
                Button("Open Accessibility Settings", action: openSettings)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                Button("I've Enabled It", action: recheck)
            }
            .padding(.top, 4)

            Button("WindowHop not showing in the list? Quit & Relaunch", action: relaunch)
                .buttonStyle(.link)
                .font(.caption)
                .padding(.top, 2)
        }
        .padding(24)
        .frame(width: 460)
    }
}
