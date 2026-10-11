import AppKit

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AreaSelector {
    private var panels: [NSPanel] = []
    private var keyMonitor: Any?
    private var completion: ((CGRect?) -> Void)?
    private var gestureStart: CGPoint?
    private var gestureRect: CGRect?
    var isSelecting: Bool { !panels.isEmpty }

    func begin(completion: @escaping (CGRect?) -> Void) {
        cancel()
        self.completion = completion
        for screen in NSScreen.screens {
            let panel = OverlayPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let view = SelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.complete = { [weak self, weak panel] rect in
                guard let panel else { return }
                self?.finish(panel.convertToScreen(rect))
            }
            panel.contentView = view
            panels.append(panel)
            panel.orderFrontRegardless()
        }
        panels.first(where: { $0.frame.contains(NSEvent.mouseLocation) })?.makeKey()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.cancel(); return nil }
            return event
        }
        NSCursor.crosshair.push()
    }
    func cancel() { if isSelecting { finish(nil) } }
    func beginGesture(at point: CGPoint, completion: @escaping (CGRect?) -> Void) {
        begin(completion: completion)
        gestureStart = point; gestureRect = nil
        // Global event tap owns this drag; overlays only render it.
        panels.forEach { $0.ignoresMouseEvents = true }
    }
    func updateGesture(to point: CGPoint) {
        guard let start = gestureStart, let panel = panels.first(where: { $0.frame.contains(start) }) else { return }
        let rect = CGRect(x: min(start.x, point.x), y: min(start.y, point.y), width: abs(start.x - point.x), height: abs(start.y - point.y)).intersection(panel.frame)
        gestureRect = rect
        (panel.contentView as? SelectionView)?.showSelection(panel.convertFromScreen(rect))
    }
    func finishGesture(at point: CGPoint) {
        updateGesture(to: point)
        guard let rect = gestureRect, rect.width >= 5, rect.height >= 5 else { cancel(); return }
        finish(rect)
    }
    private func finish(_ rect: CGRect?) {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        if let monitor = keyMonitor { NSEvent.removeMonitor(monitor) }
        keyMonitor = nil
        NSCursor.pop()
        let callback = completion
        completion = nil
        gestureStart = nil; gestureRect = nil
        callback?(rect)
    }
}

final class SelectionView: NSView {
    var complete: ((CGRect) -> Void)?
    private var start: CGPoint?
    private var selection = CGRect.zero
    override var acceptsFirstResponder: Bool { true }
    func showSelection(_ rect: CGRect) { selection = rect; needsDisplay = true }

    override func mouseDown(with event: NSEvent) {
        start = convert(event.locationInWindow, from: nil)
        selection = .zero
    }
    override func mouseDragged(with event: NSEvent) {
        guard let start else { return }
        let point = convert(event.locationInWindow, from: nil)
        selection = CGRect(x: min(start.x, point.x), y: min(start.y, point.y), width: abs(start.x - point.x), height: abs(start.y - point.y)).intersection(bounds)
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        mouseDragged(with: event)
        guard selection.width >= 5, selection.height >= 5 else { return }
        complete?(selection)
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.20).setFill()
        bounds.fill()
        if !selection.isEmpty {
            NSColor.clear.setFill()
            selection.fill(using: .copy)
            NSColor(calibratedRed: 0.67, green: 0.61, blue: 0.87, alpha: 1).setStroke()
            let outline = NSBezierPath(rect: selection)
            outline.lineWidth = 2
            outline.stroke()
        }
        let text = selection.isEmpty ? "拖动框选文字 · Esc 取消" : "\(Int(selection.width)) × \(Int(selection.height)) · 松开鼠标翻译"
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14, weight: .medium), .foregroundColor: NSColor.white]
        let size = (text as NSString).size(withAttributes: attrs)
        let x = selection.isEmpty ? bounds.midX - size.width / 2 : min(max(16, selection.minX), bounds.width - size.width - 24)
        let y = selection.isEmpty ? bounds.midY : max(20, selection.minY - 36)
        let labelRect = CGRect(x: x - 12, y: y - 7, width: size.width + 24, height: size.height + 14)
        NSColor.black.withAlphaComponent(0.78).setFill()
        NSBezierPath(roundedRect: labelRect, xRadius: 10, yRadius: 10).fill()
        (text as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attrs)
    }
}
