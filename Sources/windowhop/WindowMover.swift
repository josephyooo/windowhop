import AppKit
import ApplicationServices

enum MoveResult {
    case moved
    case noWindow
    case fullscreen
}

enum WindowMover {
    /// Returns the focused window of the frontmost app, provided it isn't us.
    /// Must be called BEFORE the overlay panel becomes key — non-activating panels
    /// don't steal activation, so `frontmostApplication` remains the user's real app.
    static func captureFocusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return nil
        }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var window: AnyObject?
        let err = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &window
        )
        guard err == .success, let window else { return nil }
        return (window as! AXUIElement)
    }

    static func attemptMove(_ window: AXUIElement?, to display: DisplayInfo) -> MoveResult {
        guard let window else { return .noWindow }
        if isFullscreen(window) { return .fullscreen }
        move(window, to: display)
        return .moved
    }

    /// Native-fullscreen windows live on their own Space and reject AX position/size
    /// changes silently. "AXFullScreen" isn't in the public constants but is the
    /// standard attribute used by every window manager on macOS.
    static func isFullscreen(_ window: AXUIElement) -> Bool {
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &value)
        guard err == .success, let num = value as? NSNumber else { return false }
        return num.boolValue
    }

    /// Centers the window on the target display at ~70% of the visible frame.
    private static func move(_ window: AXUIElement, to display: DisplayInfo) {
        let vf = display.visibleFrame
        let w = min(1600, vf.width * 0.72)
        let h = min(1000, vf.height * 0.78)
        let x = vf.origin.x + (vf.width - w) / 2
        let y = vf.origin.y + (vf.height - h) / 2

        var origin = CGPoint(x: x, y: y)
        var size = CGSize(width: w, height: h)
        guard let posValue = AXValueCreate(.cgPoint, &origin),
              let sizeValue = AXValueCreate(.cgSize, &size) else { return }

        // Set position first (gets the window onto the new display),
        // then size, then position again — some apps clamp size against the
        // *source* display's bounds on the first call, producing a half-placed window.
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
    }

    @discardableResult
    static func ensureTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    /// Forces TCC to (re)register the process in the Accessibility list without
    /// showing the system prompt. `AXIsProcessTrusted*` only reads the cache;
    /// exercising a real AX function on the system-wide element is what causes
    /// TCC to add the entry — or re-add it after the user manually deleted it.
    /// Returns the current trusted state for convenience.
    @discardableResult
    static func nudgeTCCAndCheck() -> Bool {
        let sys = AXUIElementCreateSystemWide()
        var value: AnyObject?
        _ = AXUIElementCopyAttributeValue(sys, kAXFocusedUIElementAttribute as CFString, &value)
        return AXIsProcessTrusted()
    }
}
