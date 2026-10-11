import Foundation
import CoreGraphics

public struct WindowHitRegion {
    public let owner: Int32
    public let bounds: CGRect
    public let alpha: Double
    public init(owner: Int32, bounds: CGRect, alpha: Double = 1) {
        self.owner = owner; self.bounds = bounds; self.alpha = alpha
    }
}

public enum WindowHitTesting {
    /// Regions must be onscreen and ordered from front to back, as returned by Quartz.
    public static func owner(at point: CGPoint, windows: [WindowHitRegion]) -> Int32? {
        windows.first { $0.alpha > 0.001 && $0.bounds.contains(point) }?.owner
    }
}
