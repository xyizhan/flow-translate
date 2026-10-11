import AppKit
import SwiftUI
import Combine
import ServiceManagement
import FlowCore

@MainActor final class Navigation: ObservableObject {
    @Published var page = "home"
    @Published var settingsTab = "general"
    @Published var onboarding = false
    @Published var loginMessage = ""
}
@MainActor final class ResultSession {
    let id = UUID()
    let model: TranslationModel
    let panel: NSPanel
    var automatic = false
    var anchor: CGRect
    var contentHeight: CGFloat = 70
    init(model: TranslationModel, panel: NSPanel, anchor: CGRect) { self.model = model; self.panel = panel; self.anchor = anchor }
}
@MainActor final class AppController: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let settings: AppSettings
    let learning: LearningStore
    let voice = Pronunciation()
    let navigation = Navigation()
    private let capture = ScreenCapture()
    private let selector = AreaSelector()
    private let pointerWindow = PointerWindow()
    private let hotkeys = GlobalHotkeys()
    private lazy var interactions = InteractionMonitor(settings: settings)
    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?
    private var inputPanel: NSWindow?
    private var sessions: [ResultSession] = []
    private var current: ResultSession?
    private var keyMonitor: Any?
    private var previousOptions: AppOptions?
    private var subscriptions = Set<AnyCancellable>()
    private var badgeTimer: Timer?
    init(settings: AppSettings? = nil, learning: LearningStore? = nil) {
        self.settings = settings ?? AppSettings()
        self.learning = learning ?? LearningStore()
        super.init()
    }
    var model: TranslationModel { current?.model ?? TranslationModel(settings: settings) }
    func applicationDidFinishLaunching(_ notification: Notification) {
        makeMainMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = BrandArtwork.symbol(size: 19)
        hotkeys.action = { [weak self] id in
            guard let self, !self.settings.options.paused else { return }
            switch id {
            case 1: self.lookup(at: NSEvent.mouseLocation, preferSelection: self.settings.options.preferSelection || self.settings.options.shortcuts["lookup"] == self.settings.options.shortcuts["selection"])
            case 2: self.selectArea()
            case 3: self.showInput()
            case 4: self.lookup(at: NSEvent.mouseLocation, preferSelection: true)
            default: break
            }
        }
        interactions.action = { [weak self] action in
            guard let self else { return }
            switch action {
            case .lookup(let point): self.lookup(at: point)
            case .beginArea(let point):
                self.hideTransient()
                self.selector.beginGesture(at: point) { [weak self] rect in if let rect { self?.translateArea(rect) } }
            case .updateArea(let point): self.selector.updateGesture(to: point)
            case .finishArea(let point): self.selector.finishGesture(at: point)
            case .cancel: self.selector.cancel(); self.closeTransient()
            }
        }
        interactions.automatic = { [weak self] in self?.lookup(at: $0, automatic: true) }
        interactions.ignore = { [weak self] point in
            guard let self else { return true }
            return self.selector.isSelecting || self.pointerWindow.isOwnWindow(at: point)
        }
        interactions.outsideClick = { [weak self] point in
            guard let self, !self.sessions.contains(where: { $0.panel.isVisible && $0.panel.frame.contains(point) }) else { return }
            self.closeTransient()
        }
        interactions.moved = { [weak self] point in
            guard let self, let s = self.current, s.automatic, !s.model.pinned else { return }
            if !s.anchor.union(s.panel.frame).insetBy(dx: -35, dy: -25).contains(point) { self.close(s) }
        }
        settings.onChange = { [weak self] in self?.applySettings() }
        learning.$words.receive(on: RunLoop.main).sink { [weak self] _ in self?.updateMenu() }.store(in: &subscriptions)
        badgeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateMenu(); self?.learning.objectWillChange.send() }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.keyCode == 53 else { return event }
            if self.selector.isSelecting { self.selector.cancel(); return nil }
            if let s = self.sessions.first(where: { $0.panel.isKeyWindow }) { self.close(s); return nil }
            return event
        }
        applySettings(); showPage("home")
        navigation.onboarding = !settings.options.onboardingDone
    }
    func applicationDidBecomeActive(_ notification: Notification) { settings.refreshPermissions(); interactions.start() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showPage("home"); return true }
    func applicationWillTerminate(_ notification: Notification) {
        hotkeys.unregister(); interactions.stop(); selector.cancel(); voice.stop(); badgeTimer?.invalidate()
        sessions.forEach { $0.model.cancel() }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }
    private func applySettings() {
        let o = settings.options
        if previousOptions?.shortcuts != o.shortcuts { settings.hotkeyMessage = hotkeys.register(o.shortcuts) }
        if previousOptions?.showDock != o.showDock { NSApp.setActivationPolicy(o.showDock ? .regular : .accessory) }
        NSApp.appearance = o.appearance == "light" ? NSAppearance(named: .aqua) : (o.appearance == "dark" ? NSAppearance(named: .darkAqua) : nil)
        if previousOptions != o { interactions.reset() }
        previousOptions = o; interactions.start(); updateMenu()
    }
    private func makeMainMenu() {
        let bar = NSMenu(), app = NSMenuItem(), appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "退出Flow Translate", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        app.submenu = appMenu; bar.addItem(app)
        let item = NSMenuItem(), edit = NSMenu(title: "Edit")
        for (name, action, key) in [("Undo", Selector(("undo:")), "z"), ("Cut", #selector(NSText.cut(_:)), "x"), ("Copy", #selector(NSText.copy(_:)), "c"), ("Paste", #selector(NSText.paste(_:)), "v"), ("Select All", #selector(NSText.selectAll(_:)), "a")] {
            edit.addItem(NSMenuItem(title: name, action: action, keyEquivalent: key))
        }
        item.submenu = edit; bar.addItem(item); NSApp.mainMenu = bar
    }
    private func updateMenu() {
        guard let statusItem else { return }
        let s = settings, menu = NSMenu()
        func add(_ title: String, _ action: Selector) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; menu.addItem(item)
        }
        add(s.tr("鼠标取词", "Look up word") + "     " + (s.options.shortcuts["lookup"]?.label ?? ""), #selector(hoverAction))
        add(s.tr("框选翻译", "Translate region") + "     " + (s.options.shortcuts["area"]?.label ?? ""), #selector(areaAction))
        add(s.tr("选中文字", "Translate selection") + "     " + (s.options.shortcuts["selection"]?.label ?? ""), #selector(selectionAction))
        add(s.tr("输入翻译", "Translate text") + "     " + (s.options.shortcuts["input"]?.label ?? ""), #selector(inputAction))
        menu.addItem(.separator())
        add(s.options.paused ? s.tr("恢复取词", "Resume lookup") : s.tr("暂停取词", "Pause lookup"), #selector(pauseAction))
        add(s.tr("生词本", "Vocabulary"), #selector(vocabularyAction))
        add(s.tr("复习", "Review") + " · \(learning.due.count)", #selector(reviewAction))
        add(s.tr("Flow Translate · 设置", "Flow Translate · Settings"), #selector(settingsAction))
        add(s.tr("退出Flow Translate", "Quit Flow Translate"), #selector(quitAction))
        statusItem.menu = menu
        statusItem.button?.title = s.options.reviewBadge && !learning.due.isEmpty ? " \(learning.due.count)" : ""
        statusItem.button?.appearsDisabled = s.options.paused
    }
    @objc private func areaAction() { selectArea() }
    @objc private func hoverAction() { hover() }
    @objc private func selectionAction() { translateSelection() }
    @objc private func inputAction() { showInput() }
    @objc private func settingsAction() { showSettings() }
    @objc private func vocabularyAction() { showPage("vocabulary") }
    @objc private func reviewAction() { showPage("review") }
    @objc private func pauseAction() { settings.options.paused.toggle(); closeTransient() }
    @objc private func quitAction() { NSApp.terminate(nil) }
    func showSettings(_ tab: String = "general") { navigation.settingsTab = tab; showPage("settings") }
    func showPage(_ page: String) {
        navigation.page = page
        if mainWindow == nil {
            let w = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 920, height: 690), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            w.title = "Flow Translate"; w.titleVisibility = .hidden; w.titlebarAppearsTransparent = true; w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: MainView(settings: settings, learning: learning, navigation: navigation, controller: self))
            w.minSize = CGSize(width: 820, height: 620); w.center(); mainWindow = w
        }
        settings.refreshPermissions(); mainWindow?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    private func session(anchor: CGRect, automatic: Bool = false) -> ResultSession {
        if let current, !current.model.pinned {
            current.model.cancel(); current.anchor = anchor; current.automatic = automatic
            position(current); current.panel.orderFrontRegardless(); return current
        }
        let model = TranslationModel(settings: settings)
        let panel = OverlayPanel(contentRect: CGRect(x: 0, y: 0, width: ResultMetrics.width, height: 128), styleMask: [.borderless, .resizable, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Flow Translate"
        panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = true
        panel.isReleasedWhenClosed = false; panel.isFloatingPanel = true; panel.hidesOnDeactivate = false; panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = CGSize(width: 310, height: ResultMetrics.minimumHeight); panel.maxSize = CGSize(width: 540, height: ResultMetrics.maximumHeight); panel.isMovableByWindowBackground = true; panel.delegate = self
        let s = ResultSession(model: model, panel: panel, anchor: anchor); s.automatic = automatic
        let host = NSHostingView(rootView: ResultView(model: model, learning: learning, voice: voice, preferences: settings,
            close: { [weak self, weak s] in if let s { self?.close(s) } },
            pin: { [weak self, weak s] in
                guard let self, let s else { return }
                s.model.pinned.toggle()
                if !s.model.pinned { self.closeTransient(except: s); self.current = s }
            }, openSettings: { [weak self] in self?.showSettings() },
            contentHeightChanged: { [weak self, weak s] height in
                DispatchQueue.main.async {
                    guard let self, let s, self.sessions.contains(where: { $0.id == s.id }) else { return }
                    s.contentHeight = height; self.fit(s)
                }
            }))
        host.sizingOptions = []
        panel.contentView = host
        model.onFinish = { [weak self, weak s] model in
            guard let self, let s else { return }
            self.learning.record(model.entry, target: model.targetCode, includeRecent: model.dictionary)
            if self.settings.options.autoSpeak, model.dictionary { self.speak(model.entry, automatic: true) }
            self.fit(s)
        }
        sessions.append(s); current = s; position(s); panel.orderFrontRegardless(); return s
    }
    private func position(_ s: ResultSession) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: s.anchor.midX, y: s.anchor.midY)) }) ?? NSScreen.main else { return }
        let size = CGSize(width: min(s.panel.frame.width, screen.visibleFrame.width - 24), height: min(s.panel.frame.height, screen.visibleFrame.height - 24))
        s.panel.setFrame(CGRect(origin: ScreenGeometry.popupOrigin(anchor: s.anchor, size: size, visibleFrame: screen.visibleFrame), size: size), display: true)
    }
    private func fit(_ s: ResultSession) {
        let screen = s.panel.screen ?? NSScreen.main, frame = s.panel.frame
        let limited = ResultMetrics.height(content: s.contentHeight, available: screen?.visibleFrame.height ?? 800)
        guard abs(frame.height - limited) > 1 else { return }
        var adjusted = CGRect(x: frame.minX, y: frame.maxY - limited, width: frame.width, height: limited)
        if let screen, adjusted.minY < screen.visibleFrame.minY + 12 { adjusted.origin.y = screen.visibleFrame.minY + 12 }
        s.panel.setFrame(adjusted, display: true)
    }
    private func close(_ s: ResultSession) {
        s.model.cancel(); s.panel.orderOut(nil); sessions.removeAll { $0.id == s.id }
        if current?.id == s.id { current = nil }
    }
    private func closeTransient(except: ResultSession? = nil) { for s in sessions where !s.model.pinned && s.id != except?.id { close(s) } }
    private func hideTransient() { closeTransient(); mainWindow?.orderOut(nil); inputPanel?.orderOut(nil) }
    func closeResult() { closeTransient() }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if let s = sessions.first(where: { $0.panel == sender }) { close(s); return false }; return true
    }
    private func mouseAnchor(_ point: CGPoint? = nil) -> CGRect { CGRect(origin: point ?? NSEvent.mouseLocation, size: CGSize(width: 2, height: 2)) }
    func selectArea() {
        if selector.isSelecting { selector.cancel(); return }
        if !CGPreflightScreenCaptureAccess() {
            let s = session(anchor: mouseAnchor()), id = s.model.begin("框选翻译")
            s.model.fail(AppError.message("请在设置中开启屏幕录制权限。"), id: id); return
        }
        hideTransient(); selector.begin { [weak self] rect in if let rect { self?.translateArea(rect) } }
    }
    private func translateArea(_ rect: CGRect) {
        let s = session(anchor: rect), id = s.model.begin(settings.tr("框选翻译", "Region"))
        s.model.launch(id: id) { [weak self] in
            guard let self else { throw CancellationError() }
            try await Task.sleep(for: .milliseconds(60))
            let (image, clipped) = try await self.capture.capture(rect)
            try Task.checkCancellation()
            return try await Task.detached(priority: .userInitiated) { try OCR.recognize(image, screenRect: clipped, pointer: nil, wordOnly: false) }.value
        }
    }
    func hover() { lookup(at: NSEvent.mouseLocation, preferSelection: settings.options.preferSelection) }
    func translateSelection() { lookup(at: NSEvent.mouseLocation, preferSelection: true) }
    func lookup(at pointer: CGPoint, automatic: Bool = false, preferSelection: Bool = false) {
        guard !selector.isSelecting else { return }
        if preferSelection, AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication,
           app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
           let text = try? SelectedText.read(from: app.processIdentifier), !text.isEmpty {
            session(anchor: mouseAnchor(pointer)).model.text(text, mode: settings.tr("选中文字", "Selection")); return
        }
        let rect = CGRect(x: pointer.x - 360, y: pointer.y - 130, width: 720, height: 260)
        let s = session(anchor: mouseAnchor(pointer), automatic: automatic)
        let wordOnly = settings.hoverWord, id = s.model.begin(settings.tr("语境取词", "Word lookup"), dictionary: wordOnly)
        s.model.launch(id: id) { [weak self, weak s] in
            guard let self, let s else { throw CancellationError() }
            let (image, clipped) = try await self.capture.capture(rect)
            try Task.checkCancellation()
            let result = try await Task.detached(priority: .userInitiated) { try OCR.recognize(image, screenRect: clipped, pointer: pointer, wordOnly: wordOnly) }.value
            if s.model.requestID == id { s.anchor = result.rect; self.position(s) }
            return result
        }
    }
    func translateInput(_ text: String) {
        inputPanel?.orderOut(nil)
        let s = session(anchor: mouseAnchor())
        s.model.text(text, mode: settings.tr("文本翻译", "Text"), dictionary: InputKind.isWord(text))
        s.panel.makeKeyAndOrderFront(nil)
    }
    func showEntry(_ e: WordExplanation, target: String) {
        let s = session(anchor: mouseAnchor()); s.model.cancel()
        s.model.source = e.word; s.model.output = e.meaning; s.model.explanation = e; s.model.context = e.context
        s.model.targetCode = target; s.model.dictionary = true; s.model.phase = settings.tr("已保存的释义", "Saved definition"); s.model.error = ""
        s.model.mode = settings.tr("词条详情", "Word details"); s.model.sourceCode = e.language
        fit(s); s.panel.makeKeyAndOrderFront(nil)
    }
    func showExample() { let s = session(anchor: mouseAnchor()); s.model.showExample(); fit(s); s.panel.makeKeyAndOrderFront(nil) }
    func speak(_ e: WordExplanation, automatic: Bool = false) { voice.say(e.word, language: e.language, englishVoice: settings.options.englishVoice, automatic: automatic) }
    var launchAtLogin: Bool { SMAppService.mainApp.status == .enabled }
    func setLaunchAtLogin(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            navigation.loginMessage = SMAppService.mainApp.status == .requiresApproval ? settings.tr("请在系统设置的登录项中批准Flow Translate。", "Approve Flow Translate in Login Items.") : ""
        } catch { navigation.loginMessage = error.localizedDescription }
        navigation.objectWillChange.send()
    }
    func showInput() {
        if inputPanel == nil {
            let w = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 540, height: 330), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            w.title = settings.tr("Flow Translate · 输入翻译", "Flow Translate · Text"); w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: QuickInputView(settings: settings) { [weak self] in self?.translateInput($0) })
            w.minSize = CGSize(width: 440, height: 280); w.center(); inputPanel = w
        }
        inputPanel?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
}
