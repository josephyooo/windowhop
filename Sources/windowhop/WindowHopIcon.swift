import AppKit
import CoreGraphics

enum WindowHopIcon {
    enum Style {
        case template  // menu bar: single-color, alpha-driven, adapts to dark mode
        case colored   // app icon: gradients, rounded-square background
    }

    /// Lazily-drawing NSImage — drawing happens when the image is rendered.
    /// Menu bar path uses this directly; template flag handles dark-mode inversion.
    static func makeNSImage(size: CGFloat, style: Style) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            draw(in: ctx, size: rect.width, style: style)
            return true
        }
        if style == .template {
            image.isTemplate = true
        }
        return image
    }

    /// Eager PNG export, used at build time by the `--export-icon` CLI mode
    /// to populate an .iconset for iconutil.
    static func exportPNG(pixelSize: Int, style: Style, to path: String) throws {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelSize,
            pixelsHigh: pixelSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw IconError.bitmapCreationFailed
        }

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

        guard let ctx = NSGraphicsContext.current?.cgContext else {
            throw IconError.contextUnavailable
        }
        draw(in: ctx, size: CGFloat(pixelSize), style: style)

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw IconError.pngEncodingFailed
        }
        try pngData.write(to: URL(fileURLWithPath: path))
    }

    enum IconError: Error {
        case bitmapCreationFailed
        case contextUnavailable
        case pngEncodingFailed
    }

    // MARK: - Drawing

    private static func draw(in ctx: CGContext, size: CGFloat, style: Style) {
        switch style {
        case .colored:  drawColored(in: ctx, size: size)
        case .template: drawTemplate(in: ctx, size: size)
        }
    }

    /// App-icon design ported from Resources/AppIcon.svg. All inner coords
    /// are in the SVG's 1024-unit canvas, multiplied by `u` to scale to the
    /// requested pixel size.
    private static func drawColored(in ctx: CGContext, size: CGFloat) {
        ctx.saveGState()
        defer { ctx.restoreGState() }

        let s = size
        let u = s / 1024.0

        // Use SVG-style y-down coords for everything below.
        ctx.translateBy(x: 0, y: s)
        ctx.scaleBy(x: 1, y: -1)

        let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        let bgGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                CGColor(srgbRed: 0.459, green: 0.573, blue: 0.722, alpha: 1),  // #7592b8
                CGColor(srgbRed: 0.290, green: 0.420, blue: 0.580, alpha: 1)   // #4a6b94
            ] as CFArray,
            locations: [0, 1]
        )!

        // White rounded-rect border, drawn under the tile so the visible
        // ring is the strip exposed around the tile's edges.
        ctx.setFillColor(white)
        ctx.addPath(CGPath(
            roundedRect: CGRect(x: 80*u, y: 80*u, width: 864*u, height: 864*u),
            cornerWidth: 208*u, cornerHeight: 208*u, transform: nil))
        ctx.fillPath()

        // Blue tile with vertical gradient.
        ctx.saveGState()
        ctx.addPath(CGPath(
            roundedRect: CGRect(x: 108*u, y: 108*u, width: 808*u, height: 808*u),
            cornerWidth: 180*u, cornerHeight: 180*u, transform: nil))
        ctx.clip()
        ctx.drawLinearGradient(bgGradient,
            start: CGPoint(x: 0, y: 108*u),
            end: CGPoint(x: 0, y: 916*u),
            options: [])
        ctx.restoreGState()

        // Inner content: scale 1.35× about the window's center (485, 520),
        // re-centered on the tile center (512, 512).
        ctx.saveGState()
        ctx.translateBy(x: 512*u, y: 512*u)
        ctx.scaleBy(x: 1.35, y: 1.35)
        ctx.translateBy(x: -485*u, y: -520*u)

        // Inside the inner transform, gradient endpoints have to be pre-mapped
        // through the transform's inverse so the bg sampled here lines up
        // exactly with the outer tile gradient. (Without this, the body
        // cutout / trail padding / arrow padding sample at the wrong stops
        // and look off-color from the surrounding tile.)
        let innerStart = CGPoint(x: 0, y: 220.7*u)
        let innerEnd   = CGPoint(x: 0, y: 819.3*u)
        func fillCurrentClipWithBg() {
            ctx.drawLinearGradient(bgGradient, start: innerStart, end: innerEnd, options: [])
        }

        // Window: solid white rounded rect.
        ctx.setFillColor(white)
        ctx.addPath(CGPath(
            roundedRect: CGRect(x: 270*u, y: 360*u, width: 430*u, height: 320*u),
            cornerWidth: 36*u, cornerHeight: 36*u, transform: nil))
        ctx.fillPath()

        // Body cutout: punches the gradient back through the lower part of
        // the window. Square top corners (= title-bar divider line); bottom
        // corners r=22 concentric with the outer rx=36.
        let cutout = CGMutablePath()
        cutout.move(to: CGPoint(x: 284*u, y: 438*u))
        cutout.addLine(to: CGPoint(x: 686*u, y: 438*u))
        cutout.addLine(to: CGPoint(x: 686*u, y: 644*u))
        cutout.addArc(
            tangent1End: CGPoint(x: 686*u, y: 666*u),
            tangent2End: CGPoint(x: 664*u, y: 666*u),
            radius: 22*u)
        cutout.addLine(to: CGPoint(x: 306*u, y: 666*u))
        cutout.addArc(
            tangent1End: CGPoint(x: 284*u, y: 666*u),
            tangent2End: CGPoint(x: 284*u, y: 644*u),
            radius: 22*u)
        cutout.closeSubpath()
        ctx.saveGState()
        ctx.addPath(cutout)
        ctx.clip()
        fillCurrentClipWithBg()
        ctx.restoreGState()

        // Motion-trail path (cubic with a convex control polygon — segment
        // slopes -1.56, -0.6, -0.53 — so curvature stays one-sided and there
        // is no S-curl near the arrowhead).
        let trail = CGMutablePath()
        trail.move(to: CGPoint(x: 310*u, y: 630*u))
        trail.addCurve(
            to: CGPoint(x: 700*u, y: 320*u),
            control1: CGPoint(x: 400*u, y: 490*u),
            control2: CGPoint(x: 550*u, y: 400*u))

        // Trail padding: continuous gradient strip the full length of the
        // curve. Stroke the path, convert to a fill region via
        // replacePathWithStrokedPath, clip, gradient-fill.
        ctx.saveGState()
        ctx.setLineWidth(44*u)
        ctx.setLineCap(.round)
        ctx.addPath(trail)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        fillCurrentClipWithBg()
        ctx.restoreGState()

        // Dashed motion-trail (round caps + nonzero dasharray = pill dashes).
        ctx.saveGState()
        ctx.setStrokeColor(white)
        ctx.setLineWidth(24*u)
        ctx.setLineCap(.round)
        ctx.setLineDash(phase: 0, lengths: [14*u, 38*u])
        ctx.addPath(trail)
        ctx.strokePath()
        ctx.restoreGState()

        // Arrowhead: tip up-right, base perpendicular to the trail's end
        // tangent. Pulled back along its axis so the padded tip stays well
        // inside the tile's rounded corner.
        let arrow = CGMutablePath()
        arrow.move(to: CGPoint(x: 715*u, y: 309*u))
        arrow.addLine(to: CGPoint(x: 625*u, y: 310*u))
        arrow.addLine(to: CGPoint(x: 664*u, y: 384*u))
        arrow.closeSubpath()

        // Arrowhead padding: stroke + fill, both with the bg gradient, so
        // the arrow has a small bg-colored halo separating it from the trail
        // dashes and the surrounding tile.
        ctx.saveGState()
        ctx.setLineWidth(48*u)
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.addPath(arrow)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        fillCurrentClipWithBg()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(arrow)
        ctx.clip()
        fillCurrentClipWithBg()
        ctx.restoreGState()

        // Arrowhead fill (white).
        ctx.setFillColor(white)
        ctx.addPath(arrow)
        ctx.fillPath()

        ctx.restoreGState()  // pop inner transform
    }

    /// Menu-bar template: same composition as the colored app icon (window +
    /// outgoing dashed trail + arrow up-right) but rendered single-color
    /// (alpha-driven) and tuned to remain legible at ~18pt menu-bar size via
    /// `atLeastPx` minimums on key dimensions.
    private static func drawTemplate(in ctx: CGContext, size: CGFloat) {
        ctx.saveGState()
        defer { ctx.restoreGState() }

        let s = size
        let ink = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)

        // SVG-style y-down coords (matches the colored draw).
        ctx.translateBy(x: 0, y: s)
        ctx.scaleBy(x: 1, y: -1)

        // Proportional canvas-relative geometry, with min-pixel floors so the
        // window border, dashes, and arrow stay visible at 18pt.
        let inset    = max(1.0, s * 0.045)   // border thickness around body
        let titleH   = max(2.0, s * 0.13)    // title-bar visible height
        let trailW   = max(1.4, s * 0.07)
        let dashLen  = max(1.5, s * 0.04)
        let dashGap  = max(2.0, s * 0.105)
        let padW     = max(trailW + 1.0, trailW * 1.6)
        let arrowLen = max(3.0, s * 0.18)
        let arrowHW  = max(1.5, s * 0.06)
        let arrowPad = max(1.5, s * 0.04)

        // Window: filled silhouette.
        let windowX: CGFloat = s * 0.16
        let windowY: CGFloat = s * 0.20
        let windowW: CGFloat = s * 0.62
        let windowH: CGFloat = s * 0.62
        let windowR: CGFloat = s * 0.09
        let windowRect = CGRect(x: windowX, y: windowY, width: windowW, height: windowH)
        ctx.setFillColor(ink)
        ctx.addPath(CGPath(roundedRect: windowRect, cornerWidth: windowR, cornerHeight: windowR, transform: nil))
        ctx.fillPath()

        // Body cutout: clear-blend a square-top / round-bottom region inside
        // the window, leaving a thin border + filled title bar at top.
        let cutMinX = windowX + inset
        let cutMaxX = windowX + windowW - inset
        let cutMinY = windowY + titleH                 // top of cutout (just under title bar)
        let cutMaxY = windowY + windowH - inset        // bottom of cutout
        let cutR = max(0.5, min(s * 0.04, (cutMaxX - cutMinX) / 2, (cutMaxY - cutMinY) / 2))

        let cut = CGMutablePath()
        cut.move(to: CGPoint(x: cutMinX, y: cutMinY))                                  // top-left
        cut.addLine(to: CGPoint(x: cutMaxX, y: cutMinY))                               // top-right
        cut.addLine(to: CGPoint(x: cutMaxX, y: cutMaxY - cutR))
        cut.addArc(
            tangent1End: CGPoint(x: cutMaxX, y: cutMaxY),
            tangent2End: CGPoint(x: cutMaxX - cutR, y: cutMaxY),
            radius: cutR)                                                              // bottom-right
        cut.addLine(to: CGPoint(x: cutMinX + cutR, y: cutMaxY))
        cut.addArc(
            tangent1End: CGPoint(x: cutMinX, y: cutMaxY),
            tangent2End: CGPoint(x: cutMinX, y: cutMaxY - cutR),
            radius: cutR)                                                              // bottom-left
        cut.closeSubpath()

        ctx.saveGState()
        ctx.setBlendMode(.clear)
        ctx.addPath(cut)
        ctx.fillPath()
        ctx.restoreGState()

        // Trail: cubic from inside the body's lower-left out to the upper-right.
        let trailStart = CGPoint(x: cutMinX + (cutMaxX - cutMinX) * 0.15,
                                 y: cutMaxY - (cutMaxY - cutMinY) * 0.20)
        let trailEnd   = CGPoint(x: windowX + windowW + s * 0.04,
                                 y: windowY - s * 0.03)
        let trailC1    = CGPoint(x: cutMinX + (cutMaxX - cutMinX) * 0.40,
                                 y: cutMinY + (cutMaxY - cutMinY) * 0.30)
        let trailC2    = CGPoint(x: windowX + windowW * 0.85,
                                 y: windowY + windowH * 0.10)
        let trail = CGMutablePath()
        trail.move(to: trailStart)
        trail.addCurve(to: trailEnd, control1: trailC1, control2: trailC2)

        // Trail padding: clear-blend a wider strip so dashes have a visible
        // gap punched through the window border / title bar.
        ctx.saveGState()
        ctx.setBlendMode(.clear)
        ctx.setLineWidth(padW)
        ctx.setLineCap(.round)
        ctx.addPath(trail)
        ctx.strokePath()
        ctx.restoreGState()

        // Trail dashes (pill shapes via round caps + nonzero dasharray).
        ctx.saveGState()
        ctx.setStrokeColor(ink)
        ctx.setLineWidth(trailW)
        ctx.setLineCap(.round)
        ctx.setLineDash(phase: 0, lengths: [dashLen, dashGap])
        ctx.addPath(trail)
        ctx.strokePath()
        ctx.restoreGState()

        // Arrow at trail end, oriented along the end tangent (P3 - P2 of the cubic).
        let dx = trailEnd.x - trailC2.x
        let dy = trailEnd.y - trailC2.y
        let len = max(sqrt(dx * dx + dy * dy), 0.0001)
        let dirX = dx / len
        let dirY = dy / len
        let perpX = -dirY  // perpendicular in (x, y-down)
        let perpY = dirX
        let bcX = trailEnd.x - arrowLen * dirX
        let bcY = trailEnd.y - arrowLen * dirY
        let bl = CGPoint(x: bcX - arrowHW * perpX, y: bcY - arrowHW * perpY)
        let br = CGPoint(x: bcX + arrowHW * perpX, y: bcY + arrowHW * perpY)

        let arrow = CGMutablePath()
        arrow.move(to: trailEnd)  // tip
        arrow.addLine(to: bl)
        arrow.addLine(to: br)
        arrow.closeSubpath()

        // Arrow padding: clear-blend a halo (stroke + fill) around the arrow
        // so its base separates cleanly from the trail dashes.
        ctx.saveGState()
        ctx.setBlendMode(.clear)
        ctx.setLineWidth(arrowPad)
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.addPath(arrow)
        ctx.strokePath()
        ctx.addPath(arrow)
        ctx.fillPath()
        ctx.restoreGState()

        // Arrow fill (ink).
        ctx.setFillColor(ink)
        ctx.addPath(arrow)
        ctx.fillPath()
    }
}
