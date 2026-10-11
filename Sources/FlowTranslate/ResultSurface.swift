import AppKit
import SwiftUI

enum ResultMetrics {
    static let width: CGFloat = 350
    static let minimumHeight: CGFloat = 104
    static let maximumHeight: CGFloat = 440
    static let chromeHeight: CGFloat = 64
    static func height(content: CGFloat, available: CGFloat) -> CGFloat {
        min(maximumHeight, max(1, available - 24), max(minimumHeight, ceil(content) + chromeHeight))
    }
}
struct FlowMark: View {
    var body: some View { Image(nsImage: BrandArtwork.symbol(size: 32)).resizable().interpolation(.high).aspectRatio(contentMode: .fit) }
}
/// Opaque, quiet surfaces keep contrast stable over bright or busy pages.
struct ReadingPalette {
    let dark: Bool
    private func color(_ light: UInt32, _ dark: UInt32) -> Color {
        let value = self.dark ? dark : light
        return Color(red: Double(value >> 16 & 255) / 255, green: Double(value >> 8 & 255) / 255, blue: Double(value & 255) / 255)
    }
    var paper: Color { color(0xFCFBF8, 0x1D2823) }
    var paperEnd: Color { color(0xF7F7F2, 0x19231F) }
    var ink: Color { color(0x27382F, 0xEAF0E7) }
    var secondary: Color { color(0x647268, 0xAAB9AF) }
    var subtle: Color { color(0x69796D, 0x96A69C) }
    var accent: Color { color(0x367359, 0xA3CFB2) }
    var context: Color { color(0xEDF1E9, 0x27392E) }
    var line: Color { color(0xDDE3D9, 0x3A4A40) }
    var edge: Color { color(0xD4DCCE, 0x485A4D) }
}
struct ReadingSurface: View {
    let palette: ReadingPalette
    var body: some View {
        LinearGradient(colors: [palette.paper, palette.paperEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
struct ResultContentHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
struct ResultActionStyle: ButtonStyle {
    var tint: Color = .primary
    func makeBody(configuration: Configuration) -> some View {
        ResultActionBody(label: configuration.label, pressed: configuration.isPressed, tint: tint)
    }
}
private struct ResultActionBody<Label: View>: View {
    let label: Label
    let pressed: Bool
    let tint: Color
    @State private var hovered = false
    @Environment(\.isEnabled) private var enabled
    var body: some View {
        label.font(.system(size: 10.5, weight: .medium)).frame(width: 24, height: 24)
            .background(tint.opacity(pressed ? 0.16 : (hovered ? 0.09 : 0)), in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle()).opacity(enabled ? 1 : 0.35).onHover { hovered = $0 }
    }
}
