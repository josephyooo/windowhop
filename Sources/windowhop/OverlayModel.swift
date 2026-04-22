import AppKit
import Combine

final class OverlayModel: ObservableObject {
    let displays: [DisplayInfo]
    @Published var selectedID: CGDirectDisplayID

    init(displays: [DisplayInfo], initialSelection: CGDirectDisplayID? = nil) {
        self.displays = displays
        let initial = initialSelection.flatMap { id in displays.first(where: { $0.id == id })?.id }
            ?? displays.first(where: { $0.isPrimary })?.id
            ?? displays.first!.id
        self.selectedID = initial
    }

    var selected: DisplayInfo? {
        displays.first(where: { $0.id == selectedID })
    }

    /// Picks the nearest display in the requested direction using center-to-center
    /// vectors, with a perpendicular-distance penalty so "right" prefers displays
    /// that actually line up horizontally.
    func moveSelection(dx: Int, dy: Int) {
        guard let current = selected else { return }
        let c = CGPoint(x: current.bounds.midX, y: current.bounds.midY)

        var best: DisplayInfo?
        var bestScore = CGFloat.infinity

        for d in displays where d.id != current.id {
            let target = CGPoint(x: d.bounds.midX, y: d.bounds.midY)
            let vx = target.x - c.x
            let vy = target.y - c.y

            if dx > 0 && vx <= 0 { continue }
            if dx < 0 && vx >= 0 { continue }
            if dy > 0 && vy <= 0 { continue }
            if dy < 0 && vy >= 0 { continue }

            let parallel = dx != 0 ? abs(vx) : abs(vy)
            let perpendicular = dx != 0 ? abs(vy) : abs(vx)
            let score = parallel + perpendicular * 2

            if score < bestScore {
                bestScore = score
                best = d
            }
        }

        if let best {
            selectedID = best.id
        }
    }

    func selectByNumber(_ n: Int) {
        guard n >= 1, n <= displays.count else { return }
        selectedID = displays[n - 1].id
    }
}
