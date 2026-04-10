import SwiftUI
import AppKit

struct OverlayView: View {
    @ObservedObject var model: OverlayModel
    let onSelect: (DisplayInfo) -> Void

    private let canvasSize = CGSize(width: 560, height: 340)
    private let padding: CGFloat = 36

    private var boundingBox: CGRect {
        model.displays.reduce(CGRect.null) { $0.union($1.bounds) }
    }

    private var scale: CGFloat {
        let bb = boundingBox
        guard bb.width > 0, bb.height > 0 else { return 1 }
        let sx = (canvasSize.width - 2 * padding) / bb.width
        let sy = (canvasSize.height - 2 * padding) / bb.height
        return min(sx, sy)
    }

    private func rect(for display: DisplayInfo) -> CGRect {
        let bb = boundingBox
        let s = scale
        let scaledW = bb.width * s
        let scaledH = bb.height * s
        let offsetX = (canvasSize.width - scaledW) / 2
        let offsetY = (canvasSize.height - scaledH) / 2
        let b = display.bounds
        return CGRect(
            x: offsetX + (b.origin.x - bb.origin.x) * s,
            y: offsetY + (b.origin.y - bb.origin.y) * s,
            width: b.width * s,
            height: b.height * s
        )
    }

    var body: some View {
        ZStack {
            VisualEffectBackground()

            ZStack(alignment: .topLeading) {
                ForEach(Array(model.displays.enumerated()), id: \.element.id) { index, display in
                    let r = rect(for: display)
                    DisplayTile(
                        display: display,
                        index: index + 1,
                        selected: display.id == model.selectedID
                    )
                    .frame(width: r.width, height: r.height)
                    .offset(x: r.origin.x, y: r.origin.y)
                    .onTapGesture { onSelect(display) }
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct DisplayTile: View {
    let display: DisplayInfo
    let index: Int
    let selected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.30, green: 0.30, blue: 0.48),
                            Color(red: 0.98, green: 0.60, blue: 0.22)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(0.35))
                    .frame(height: 10)
                Spacer(minLength: 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(spacing: 2) {
                Text("\(index)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(display.name)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .padding(.horizontal, 4)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    selected ? Color.accentColor : Color.white.opacity(0.18),
                    lineWidth: selected ? 3 : 1
                )
        )
        .shadow(
            color: selected ? Color.accentColor.opacity(0.55) : Color.black.opacity(0.25),
            radius: selected ? 14 : 6,
            y: 2
        )
        .scaleEffect(selected ? 1.035 : 1.0)
        .animation(.easeOut(duration: 0.12), value: selected)
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.state = .active
        v.blendingMode = .behindWindow
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
