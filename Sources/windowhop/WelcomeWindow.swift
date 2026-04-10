import AppKit
import SwiftUI

@MainActor
final class WelcomeWindowController {
    private var window: NSWindow?
    private var pollTimer: Timer?

    var isVisible: Bool { window?.isVisible == true }

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
            recheck: { [weak self] in self?.checkNow() }
        )
        w.contentView = NSHostingView(rootView: view)
        self.window = w

        // Kick the system prompt so WindowHop appears in the Accessibility list.
        WindowMover.ensureTrusted(prompt: true)

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

    private func checkNow() {
        if WindowMover.ensureTrusted(prompt: false) {
            dismiss()
        }
    }

    private func dismiss() {
        pollTimer?.invalidate()
        pollTimer = nil
        window?.orderOut(nil)
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct WelcomeView: View {
    let openSettings: () -> Void
    let recheck: () -> Void

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
        }
        .padding(24)
        .frame(width: 460)
    }
}
