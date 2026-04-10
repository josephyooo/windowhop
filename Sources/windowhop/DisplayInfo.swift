import AppKit

struct DisplayInfo: Identifiable, Equatable, Hashable {
    let id: CGDirectDisplayID
    let name: String
    let bounds: CGRect        // top-left origin, full display bounds (from CGDisplayBounds)
    let visibleFrame: CGRect  // top-left origin, excludes menu bar + Dock
    let isPrimary: Bool

    static func all() -> [DisplayInfo] {
        guard let primary = NSScreen.screens.first else { return [] }
        let primaryHeight = primary.frame.height

        return NSScreen.screens.compactMap { screen in
            guard let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            let displayID = num.uint32Value
            let bounds = CGDisplayBounds(displayID)

            // NSScreen.visibleFrame is AppKit (bottom-left origin of primary). Flip to top-left.
            let vf = screen.visibleFrame
            let topY = primaryHeight - (vf.origin.y + vf.height)
            let visibleTopLeft = CGRect(x: vf.origin.x, y: topY, width: vf.width, height: vf.height)

            return DisplayInfo(
                id: displayID,
                name: screen.localizedName,
                bounds: bounds,
                visibleFrame: visibleTopLeft,
                isPrimary: CGDisplayIsMain(displayID) != 0
            )
        }
    }
}
