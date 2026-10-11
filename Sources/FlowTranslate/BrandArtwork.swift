import AppKit

/// Two open speech ribbons exchange direction around a quiet center.
/// Shared vector artwork keeps the app icon and small monochrome mark consistent.
enum BrandArtwork {
    static func ribbon(in rect: CGRect, lower: Bool) -> NSBezierPath {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            let x = lower ? 1 - x : x, y = lower ? 1 - y : y
            return CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        let path = NSBezierPath()
        path.move(to: p(0.24, 0.47))
        path.curve(to: p(0.47, 0.75), controlPoint1: p(0.24, 0.65), controlPoint2: p(0.31, 0.75))
        path.line(to: p(0.78, 0.75))
        path.line(to: p(0.67, 0.62))
        path.lineWidth = rect.width * 0.105
        path.lineCapStyle = .round; path.lineJoinStyle = .round
        return path
    }
    static func symbol(size: CGFloat) -> NSImage {
        let image = NSImage(size: CGSize(width: size, height: size), flipped: false) { rect in
            NSColor.black.setStroke()
            ribbon(in: rect, lower: false).stroke(); ribbon(in: rect, lower: true).stroke()
            return true
        }
        image.isTemplate = true; image.accessibilityDescription = "Flow Translate"
        return image
    }
    static func drawIcon() {
        let tile = NSBezierPath(roundedRect: CGRect(x: 58, y: 58, width: 908, height: 908), xRadius: 212, yRadius: 212)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.16)
        shadow.shadowBlurRadius = 24; shadow.shadowOffset = CGSize(width: 0, height: -9); shadow.set()
        NSColor(calibratedRed: 0.06, green: 0.22, blue: 0.25, alpha: 1).setFill(); tile.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(colors: [NSColor(calibratedRed: 0.10, green: 0.33, blue: 0.36, alpha: 1), NSColor(calibratedRed: 0.025, green: 0.115, blue: 0.17, alpha: 1)])!.draw(in: tile, angle: -65)
        NSColor.white.withAlphaComponent(0.16).setStroke(); tile.lineWidth = 2; tile.stroke()
        let mark = CGRect(x: 60, y: 60, width: 904, height: 904)
        NSGraphicsContext.saveGraphicsState()
        let ribbonShadow = NSShadow(); ribbonShadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
        ribbonShadow.shadowBlurRadius = 14; ribbonShadow.shadowOffset = CGSize(width: 0, height: -6); ribbonShadow.set()
        NSColor(calibratedRed: 0.60, green: 0.93, blue: 0.84, alpha: 1).setStroke()
        ribbon(in: mark, lower: false).stroke()
        NSColor(calibratedRed: 0.92, green: 0.98, blue: 0.96, alpha: 1).setStroke()
        ribbon(in: mark, lower: true).stroke()
        NSGraphicsContext.restoreGraphicsState()
    }
}
