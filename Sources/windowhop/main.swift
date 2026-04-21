import AppKit

// Build-time icon export: render the icon at a given pixel size and exit.
// Invoked by build.sh to populate an .iconset before iconutil runs.
// Optional fourth arg picks the style: "colored" (default) or "template".
if CommandLine.arguments.count >= 4, CommandLine.arguments[1] == "--export-icon" {
    guard let size = Int(CommandLine.arguments[2]) else {
        FileHandle.standardError.write(Data("usage: windowhop --export-icon <size> <path> [colored|template]\n".utf8))
        exit(2)
    }
    let path = CommandLine.arguments[3]
    let style: WindowHopIcon.Style = {
        if CommandLine.arguments.count >= 5, CommandLine.arguments[4] == "template" {
            return .template
        }
        return .colored
    }()
    do {
        try WindowHopIcon.exportPNG(pixelSize: size, style: style, to: path)
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("icon export failed: \(error)\n".utf8))
        exit(1)
    }
}

MainActor.assumeIsolated {
    let delegate = AppDelegate()
    NSApplication.shared.delegate = delegate
    NSApplication.shared.setActivationPolicy(.accessory)
    NSApplication.shared.run()
}
