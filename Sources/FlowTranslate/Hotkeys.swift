import AppKit
import Carbon

@MainActor
final class GlobalHotkeys {
    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    var action: ((UInt32) -> Void)?
    func register(_ shortcuts: [String: Shortcut]) -> String {
        unregister()
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &id)
            let owner = Unmanaged<GlobalHotkeys>.fromOpaque(userData).takeUnretainedValue()
            let value = id.id
            Task { @MainActor in owner.action?(value) }
            return noErr
        }, 1, &type, pointer, &handler)
        guard status == noErr else { return "全局快捷键监听失败（\(status)）。仍可使用菜单栏操作。" }
        let keys: [(UInt32, String)] = [(1, "lookup"), (2, "area"), (3, "input"), (4, "selection")]
        var failed: [String] = []
        var registered = Set<String>()
        for (id, kind) in keys {
            guard let shortcut = shortcuts[kind] else { continue }
            let identity = "\(shortcut.keyCode):\(shortcut.modifiers)"
            // Shared lookup/selection shortcuts are handled by the selection-first lookup action.
            if registered.contains(identity) {
                if kind != "selection" || shortcuts["lookup"] != shortcut { failed.append("\(kind): \(shortcut.label)") }
                continue
            }
            var ref: EventHotKeyRef?
            let result = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, EventHotKeyID(signature: 0x464C5452, id: id), GetApplicationEventTarget(), 0, &ref)
            if result == noErr, let ref { refs.append(ref); registered.insert(identity) } else { failed.append(shortcut.label) }
        }
        return failed.isEmpty ? "" : "快捷键 \(failed.joined(separator: "、")) 已被占用；请使用菜单栏。"
    }
    func unregister() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }
}

enum SelectedText {
    static func read(from pid: pid_t) throws -> String {
        guard AXIsProcessTrusted() else { throw AppError.message("选中文字翻译需要辅助功能权限。框选翻译不需要这项权限。") }
        let app = AXUIElementCreateApplication(pid)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            throw AppError.message("当前应用没有提供可读取的选中文字。请使用 ⌥ R 框选。")
        }
        let element = unsafeBitCast(focused, to: AXUIElement.self)
        var selected: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selected) == .success,
              let text = selected as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.message("没有读到选中文字。请先选择文本，或使用 ⌥ R 框选。")
        }
        return text
    }
}
