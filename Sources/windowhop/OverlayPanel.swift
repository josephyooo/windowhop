import AppKit

final class OverlayPanel: NSPanel {
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?
    var onArrow: ((Int, Int) -> Void)?
    var onNumber: ((Int) -> Void)?

    init(contentSize: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53:  // esc
            onCancel?()
        case 36, 76:  // return, numpad enter
            onCommit?()
        case 123:  // left
            onArrow?(-1, 0)
        case 124:  // right
            onArrow?(1, 0)
        case 125:  // down
            onArrow?(0, 1)
        case 126:  // up
            onArrow?(0, -1)
        default:
            if let chars = event.charactersIgnoringModifiers,
               let n = Int(chars), n >= 1, n <= 9 {
                onNumber?(n)
            } else {
                super.keyDown(with: event)
            }
        }
    }

    override func resignKey() {
        super.resignKey()
        onCancel?()
    }
}
