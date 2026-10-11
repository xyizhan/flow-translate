import AppKit
import FlowCore

@MainActor
final class InteractionMonitor {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var timer: Timer?
    private var machine = LookupGestureMachine()
    private var hover = HoverGate()
    private var modifierDown = false
    private var lastPoint = CGPoint.zero
    private var lastPressTime: TimeInterval = 0
    let settings: AppSettings
    var action: ((LookupGestureAction) -> Void)?
    var automatic: ((CGPoint) -> Void)?
    var moved: ((CGPoint) -> Void)?
    var outsideClick: ((CGPoint) -> Void)?
    var ignore: ((CGPoint) -> Bool)?
    init(settings: AppSettings) { self.settings = settings }
    func start() {
        guard tap == nil else { return }
        guard AXIsProcessTrusted() else {
            settings.triggerMessage = settings.tr("开启辅助功能后，可使用 Option 点按、点击和拖动取词。", "Enable Accessibility for Option tap, click, and drag.")
            return
        }
        let types: [CGEventType] = [.flagsChanged, .keyDown, .leftMouseDown, .leftMouseUp, .leftMouseDragged, .mouseMoved, .scrollWheel]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            return MainActor.assumeIsolated {
                let owner = Unmanaged<InteractionMonitor>.fromOpaque(info).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = owner.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                    owner.machine.reset(); owner.hover.reset(); owner.modifierDown = false
                    owner.action?(.cancel)
                    return Unmanaged.passUnretained(event)
                }
                return owner.handle(type, event: event) ? nil : Unmanaged.passUnretained(event)
            }
        }, userInfo: pointer)
        guard let tap else {
            settings.triggerMessage = settings.tr("全局手势监听不可用，请检查辅助功能权限后重开Flow Translate。", "Gesture monitoring is unavailable. Check Accessibility and reopen Flow Translate.")
            return
        }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        CGEvent.tapEnable(tap: tap, enable: true)
        settings.triggerMessage = settings.tr("手势监听已开启。", "Gesture monitoring is active.")
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkHover() }
        }
        RunLoop.main.add(timer, forMode: .common); self.timer = timer
    }
    func stop() {
        timer?.invalidate(); timer = nil
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        source = nil; tap = nil; machine.reset(); hover.reset(); modifierDown = false
    }
    func reset() { machine.reset(); hover.reset(); modifierDown = false }
    private func allowed(_ point: CGPoint) -> Bool {
        suppressionReason(at: point) == nil
    }
    private func suppressionReason(at point: CGPoint) -> String? {
        if settings.options.paused { return settings.tr("取词已暂停。", "Lookup is paused.") }
        if ignore?(point) == true { return settings.tr("鼠标位于Flow Translate窗口或框选层中，已忽略取词。", "Lookup ignored over a Flow Translate window or selection overlay.") }
        guard let front = NSWorkspace.shared.frontmostApplication else { return settings.tr("没有可用的前台应用。", "No foreground application is available.") }
        let bundle = front.bundleIdentifier ?? ""
        let excluded = settings.options.excludedApps.components(separatedBy: CharacterSet(charactersIn: ",\n;")).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if excluded.contains(bundle) || excluded.contains(front.localizedName ?? "") {
            return settings.tr("当前应用在取词排除列表中。", "The foreground app is excluded from lookup.")
        }
        return nil
    }
    private func matches(_ flags: CGEventFlags) -> Bool {
        let relevant = flags.intersection([.maskAlternate, .maskCommand, .maskControl, .maskShift])
        switch settings.options.modifier {
        case "leftOption", "rightOption": return relevant == .maskAlternate
        case "controlOption": return relevant == [.maskAlternate, .maskControl]
        default: return false
        }
    }
    private func pressedModifierMatches(_ flags: CGEventFlags) -> Bool {
        guard matches(flags) else { return false }
        switch settings.options.modifier {
        case "leftOption": return CGEventSource.keyState(.combinedSessionState, key: 58)
        case "rightOption": return CGEventSource.keyState(.combinedSessionState, key: 61)
        case "controlOption": return true
        default: return false
        }
    }
    private func handle(_ type: CGEventType, event: CGEvent) -> Bool {
        let raw = event.location
        let point = CGPoint(x: raw.x, y: (NSScreen.screens.first?.frame.height ?? 0) - raw.y)
        lastPoint = point
        let now = ProcessInfo.processInfo.systemUptime
        let p = settings.options
        let preferences = GesturePreferences(tap: p.modifierTap, click: p.modifierClick, drag: p.modifierDrag, plainClick: p.plainClick)
        var input: LookupGestureEvent?
        if type == .flagsChanged {
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            let specific = p.modifier == "leftOption" ? code == 58 : (p.modifier == "rightOption" ? code == 61 : (code == 58 || code == 61 || code == 59 || code == 62))
            let active = matches(event.flags)
            if !active, modifierDown {
                modifierDown = false
                let allowedRelease: Bool
                if p.modifier == "controlOption" {
                    allowedRelease = specific && event.flags.intersection([.maskCommand, .maskShift]).isEmpty
                } else {
                    allowedRelease = specific && !event.flags.contains(.maskAlternate)
                }
                if !allowedRelease { _ = machine.handle(.key, preferences: preferences) }
                input = .modifierUp(time: now, point: point)
            } else if specific && active && !modifierDown {
                if let reason = suppressionReason(at: point) { settings.triggerMessage = reason }
                else {
                    settings.triggerMessage = settings.tr("已收到取词修饰键。", "Lookup modifier received.")
                    modifierDown = true; input = .modifierDown(time: now)
                }
            } else if !specific && modifierDown { input = .key }
        } else if type == .keyDown {
            hover.reset()
            if event.getIntegerValueField(.keyboardEventKeycode) == 53, !machine.isInteracting {
                DispatchQueue.main.async { [weak self] in self?.action?(.cancel) }
            }
            input = event.getIntegerValueField(.keyboardEventKeycode) == 53 ? .escape : .key
        } else if type == .leftMouseDown {
            hover.reset()
            if !machine.isInteracting { outsideClick?(point) }
            if !machine.isInteracting, let reason = suppressionReason(at: point) {
                if matches(event.flags) { settings.triggerMessage = reason }
                _ = machine.handle(.key, preferences: preferences); return false
            }
            lastPressTime = now
            // The modifier may have been pressed while the pointer was over our UI.
            // At mouse-down, use its current state rather than requiring that earlier event.
            let modified = pressedModifierMatches(event.flags)
            if modified { modifierDown = true }
            input = .down(point: point, modified: modified)
        } else if type == .leftMouseUp {
            input = .up(point: point)
        } else if type == .mouseMoved || type == .leftMouseDragged {
            if allowed(point) && type == .mouseMoved { hover.move(to: point, now: now) } else { hover.reset() }
            moved?(point)
            input = .move(point: point)
        } else if type == .scrollWheel { hover.reset(); input = .scroll }
        guard let input else { return false }
        let result = machine.handle(input, preferences: preferences)
        // The tap callback performs only state transitions; expensive work is deferred.
        for item in result.actions {
            switch item {
            case .lookup: settings.triggerMessage = settings.tr("已触发取词。", "Word lookup triggered.")
            case .beginArea: settings.triggerMessage = settings.tr("已触发拖动框选。", "Drag selection triggered.")
            default: break
            }
            DispatchQueue.main.async { [weak self] in self?.action?(item) }
        }
        return result.consume
    }
    private func checkHover() {
        // If macOS or another event tap drops mouse-up, never leave an overlay
        // trapping the desktop. Consult physical state after the down event settles.
        if machine.isInteracting, ProcessInfo.processInfo.systemUptime - lastPressTime > 0.2,
           !CGEventSource.buttonState(.hidSystemState, button: .left) {
            machine.reset(); hover.reset(); modifierDown = false; action?(.cancel)
        }
        guard settings.options.autoHover, !modifierDown, !machine.isInteracting, allowed(lastPoint) else { hover.reset(); return }
        if let point = hover.ready(now: ProcessInfo.processInfo.systemUptime, delay: min(2, max(0.35, settings.options.hoverDelay))) { automatic?(point) }
    }
}
