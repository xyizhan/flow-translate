import Foundation
import CoreGraphics

public enum LookupGestureAction: Equatable {
    case lookup(CGPoint), beginArea(CGPoint), updateArea(CGPoint), finishArea(CGPoint), cancel
}
public struct GestureDecision {
    public var consume: Bool = false
    public var actions: [LookupGestureAction] = []
    public init(consume: Bool = false, actions: [LookupGestureAction] = []) { self.consume = consume; self.actions = actions }
}
public enum LookupGestureEvent {
    case modifierDown(time: TimeInterval)
    case modifierUp(time: TimeInterval, point: CGPoint)
    case key, scroll
    case down(point: CGPoint, modified: Bool)
    case move(point: CGPoint)
    case up(point: CGPoint)
    case escape
}
public struct GesturePreferences: Equatable {
    public var tap = true, click = true, drag = true, plainClick = false
    public init(tap: Bool = true, click: Bool = true, drag: Bool = true, plainClick: Bool = false) {
        self.tap = tap; self.click = click; self.drag = drag; self.plainClick = plainClick
    }
}
/// Tracks a physical modifier gesture; chords and scrolling invalidate the tap.
public struct LookupGestureMachine {
    private var pressedAt: TimeInterval?
    private var tapValid = false
    private var origin: CGPoint?
    private var dragging = false
    private var modifiedGesture = false
    private var plainOrigin: CGPoint?
    public init() {}
    public var isDragging: Bool { dragging }
    public var isInteracting: Bool { origin != nil }
    public mutating func reset() { self = Self() }
    public mutating func handle(_ event: LookupGestureEvent, preferences p: GesturePreferences) -> GestureDecision {
        switch event {
        case .modifierDown(let t):
            pressedAt = t; tapValid = true
        case .modifierUp(let t, let point):
            defer { pressedAt = nil; tapValid = false }
            if p.tap, tapValid, origin == nil, let start = pressedAt, t >= start {
                return GestureDecision(actions: [.lookup(point)])
            }
        case .key, .scroll:
            tapValid = false
        case .down(let point, let modified):
            tapValid = false
            if modified && (p.click || p.drag) {
                origin = point; modifiedGesture = true; dragging = false
                return GestureDecision(consume: true)
            }
            if p.plainClick && !modified { plainOrigin = point }
        case .move(let point):
            if let start = origin, p.drag {
                if !dragging, hypot(point.x - start.x, point.y - start.y) >= 5 {
                    dragging = true
                    return GestureDecision(consume: true, actions: [.beginArea(start), .updateArea(point)])
                }
                if dragging { return GestureDecision(consume: true, actions: [.updateArea(point)]) }
            }
            if let start = plainOrigin, hypot(point.x - start.x, point.y - start.y) > 5 { plainOrigin = nil }
            return GestureDecision(consume: origin != nil)
        case .up(let point):
            defer { origin = nil; dragging = false; modifiedGesture = false; plainOrigin = nil }
            if origin != nil {
                if dragging { return GestureDecision(consume: true, actions: [.finishArea(point)]) }
                if p.click && modifiedGesture { return GestureDecision(consume: true, actions: [.lookup(point)]) }
                return GestureDecision(consume: true)
            }
            if p.plainClick, let start = plainOrigin, hypot(point.x - start.x, point.y - start.y) <= 5 {
                return GestureDecision(actions: [.lookup(point)])
            }
        case .escape:
            let active = origin != nil
            reset()
            return GestureDecision(consume: active, actions: active ? [.cancel] : [])
        }
        return GestureDecision()
    }
}

public struct HoverGate {
    private var origin: CGPoint?
    private var since: TimeInterval = 0
    private var fired: CGPoint?
    public init() {}
    public mutating func reset() { self = Self() }
    public mutating func move(to point: CGPoint, now: TimeInterval) {
        if origin == nil || hypot(point.x - origin!.x, point.y - origin!.y) > 6 { origin = point; since = now }
        if let previous = fired, hypot(point.x - previous.x, point.y - previous.y) > 12 { fired = nil }
    }
    public mutating func ready(now: TimeInterval, delay: TimeInterval) -> CGPoint? {
        guard let point = origin, fired == nil, now - since >= delay else { return nil }
        fired = point; return point
    }
}

public enum InputKind {
    public static func isWord(_ input: String) -> Bool {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 80, text.contains(where: \.isLetter) else { return false }
        return text.allSatisfy { $0.isLetter || $0.isNumber || "-_’'".contains($0) }
    }
}
