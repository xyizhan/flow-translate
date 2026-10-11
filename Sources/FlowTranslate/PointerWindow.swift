import AppKit
import FlowCore

@MainActor
final class PointerWindow {
    private var snapshot: [WindowHitRegion] = []
    private var sampledAt: TimeInterval = -.infinity
    private var frontPID: pid_t?

    func isOwnWindow(at point: CGPoint) -> Bool {
        // A visible NSWindow may be behind another app or on another Space.
        // Its rectangle alone must never suppress lookup in the foreground document.
        guard NSApp.windows.contains(where: { $0.isVisible && $0.isOnActiveSpace && $0.frame.contains(point) }) else { return false }
        let now = ProcessInfo.processInfo.systemUptime
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        if now - sampledAt >= 0.1 || front != frontPID {
            guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
                return NSApp.isActive
            }
            // Keep only geometry and ownership; never store window titles or contents.
            snapshot = windows.compactMap { info in
                guard let pid = info[kCGWindowOwnerPID as String] as? NSNumber,
                      let value = info[kCGWindowBounds as String] as? [String: Any],
                      let bounds = CGRect(dictionaryRepresentation: value as CFDictionary) else { return nil }
                return WindowHitRegion(owner: pid.int32Value, bounds: bounds,
                    alpha: (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1)
            }
            sampledAt = now; frontPID = front
        }
        let quartzPoint = CGPoint(x: point.x, y: (NSScreen.screens.first?.frame.height ?? 0) - point.y)
        return WindowHitTesting.owner(at: quartzPoint, windows: snapshot) == ProcessInfo.processInfo.processIdentifier
    }
}
