import AppKit
import SwiftUI
import Translation
import FlowCore

enum Palette {
    static let background = Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(calibratedWhite: 0.105, alpha: 1) : NSColor(calibratedRed: 0.982, green: 0.978, blue: 0.967, alpha: 1) })
    static let sidebar = Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(calibratedWhite: 0.14, alpha: 1) : NSColor(calibratedRed: 0.947, green: 0.943, blue: 0.931, alpha: 1) })
    static let card = Color(nsColor: .controlBackgroundColor)
    static let stroke = Color.primary.opacity(0.085)
}
struct Paper<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View { content().padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Palette.card, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.stroke)) }
}
struct QuietButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.05), in: RoundedRectangle(cornerRadius: 7))
    }
}
struct MainView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var learning: LearningStore
    @ObservedObject var navigation: Navigation
    let controller: AppController
    private func tr(_ zh: String, _ en: String) -> String { settings.tr(zh, en) }
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Palette.stroke).frame(width: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if !learning.error.isEmpty {
                        Paper {
                            Text(learning.error).font(.caption).foregroundStyle(.orange)
                            if learning.canRecover { Button(tr("恢复最近备份", "Restore last backup")) { learning.recoverBackup() } }
                        }
                    }
                    switch navigation.page {
                    case "vocabulary": VocabularyPage(settings: settings, learning: learning, controller: controller)
                    case "review": ReviewPage(settings: settings, learning: learning, controller: controller)
                    case "settings": SettingsPage(settings: settings, navigation: navigation, controller: controller)
                    default: home
                    }
                }.padding(.horizontal, 36).padding(.top, 54).padding(.bottom, 36)
                .frame(maxWidth: 840, alignment: .leading).frame(maxWidth: .infinity, alignment: .top)
            }.background(Palette.background)
        }
        .font(.system(size: 13)).tint(.primary)
        .sheet(isPresented: $navigation.onboarding) { OnboardingView(settings: settings, navigation: navigation, controller: controller) }
        .ignoresSafeArea()
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                FlowMark().frame(width: 26, height: 26).foregroundStyle(Color(red: 0.18, green: 0.48, blue: 0.43))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Flow Translate").font(.system(size: 16, weight: .semibold, design: .rounded)).tracking(-0.5).fixedSize()
                    Text("KEEP IN THE FLOW").font(.system(size: 7, weight: .medium)).tracking(1.0).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 18).padding(.top, 66).padding(.bottom, 38)
            VStack(spacing: 8) {
                nav("home", tr("首页", "Home"), "house")
                nav("vocabulary", tr("生词本", "Vocabulary"), "book.closed")
                nav("review", tr("复习", "Review"), "rectangle.on.rectangle")
                nav("settings", tr("设置", "Settings"), "slider.horizontal.3")
            }.padding(.horizontal, 12)
            Spacer()
            VStack(alignment: .leading, spacing: 13) {
                Button { settings.options.paused.toggle() } label: {
                    Label(settings.options.paused ? tr("已暂停 · 点击恢复", "Paused · Resume") : tr("随时为你翻译", "Ready when you are"), systemImage: settings.options.paused ? "pause.circle" : "circle.fill")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }.buttonStyle(.plain)
                Divider()
                HStack { Text("v\(BuildIdentity.version)").font(.system(size: 10, design: .monospaced)); Spacer(); Button(tr("使用指南", "Guide")) { navigation.onboarding = true }.buttonStyle(.plain).font(.system(size: 10)) }.foregroundStyle(.secondary)
            }.padding(22)
        }.frame(width: 198).frame(maxHeight: .infinity).background(Palette.sidebar)
    }
    private func nav(_ id: String, _ label: String, _ icon: String) -> some View {
        Button { navigation.page = id } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).frame(width: 18)
                Text(label); Spacer()
                if id == "review", !learning.due.isEmpty { Text("\(learning.due.count)").font(.system(size: 10)).padding(.horizontal, 6).padding(.vertical, 3).background(Color.primary.opacity(0.07), in: Capsule()) }
            }.font(.system(size: 13, weight: navigation.page == id ? .semibold : .regular)).padding(.horizontal, 14).padding(.vertical, 12)
                .background(navigation.page == id ? Palette.card : .clear, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(navigation.page == id ? Palette.stroke : .clear))
        }.buttonStyle(.plain)
    }
    private var home: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 13) {
                Text(tr("让阅读，保持连贯。", "Stay in the flow.")).font(.system(size: 31, weight: .semibold))
                    .background(alignment: .bottom) { Rectangle().fill(Color.teal.opacity(0.12)).frame(height: 8).offset(y: 1) }
                Text(tr("遇见陌生的词，轻按 Option。理解，然后继续。", "Tap Option on a word. Understand it. Keep reading.")).foregroundStyle(.secondary).font(.system(size: 12))
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metric(tr("次取词", "lookups"), learning.lookupCount, tr("理解眼前的文字", "Understand what you are reading"))
                metric(tr("已收藏", "saved"), learning.words.count, tr("留在你的生词本", "Keep it in your vocabulary"))
                metric(tr("待复习", "due"), learning.due.count, tr("今天再熟悉一点", "Make it more familiar today"))
                metric(tr("已掌握", "mastered"), learning.masteredCount, tr("下次遇见，更加从容", "Recognize it next time"))
            }
            if !settings.screenPermission || !settings.accessibilityPermission || settings.keyRequiresUnlock || settings.needsAPIKey {
                Paper {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "info.circle").foregroundStyle(.secondary)
                        Text(settings.needsAPIKey && !settings.keyRequiresUnlock ? tr("先配置翻译服务，再试一次输入翻译。", "Set up a translation service, then try translating text.") : (settings.keyRequiresUnlock ? tr("API Key 需要授权读取。可以在设置里主动解锁。", "Unlock your API key in Settings when you are ready.") : tr("完成权限设置，即可使用所有取词方式。", "Finish permissions to enable every lookup gesture."))).font(.system(size: 12))
                        Spacer()
                        Button(tr("去设置", "Settings")) { controller.showSettings(settings.needsAPIKey || settings.keyRequiresUnlock ? "api" : "general") }.buttonStyle(QuietButton())
                    }
                }
            }
            HStack {
                Text(tr("最近查询", "Recent lookups")).font(.system(size: 15, weight: .semibold))
                Spacer()
                Button(tr("输入翻译", "Translate text")) { controller.showInput() }.buttonStyle(.plain).foregroundStyle(.secondary).font(.system(size: 11))
            }
            if learning.recent.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.cursor").font(.system(size: 24)).foregroundStyle(.tertiary)
                    Text(tr("把鼠标移到一个词上，轻按左 Option。", "Place the pointer on a word and tap left Option.")).foregroundStyle(.secondary)
                    Text(tr("也可以按 Option + R，框选一段文字。", "Or press Option + R to translate a region.")).font(.system(size: 11)).foregroundStyle(.tertiary)
                    Button(tr("开始框选", "Select a region")) { controller.selectArea() }.buttonStyle(QuietButton())
                }.frame(maxWidth: .infinity).padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(learning.recent.prefix(8)) { item in
                        HStack(spacing: 12) {
                            Button { controller.showEntry(item.explanation, target: item.target) } label: {
                                HStack(spacing: 16) {
                                    Text(item.explanation.word).font(.system(size: 14, weight: .medium)).lineLimit(1).frame(width: 140, alignment: .leading)
                                    Text(item.explanation.meaning).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                                }.contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            SaveWordButton(explanation: item.explanation, target: item.target, store: learning)
                            Text(item.date, style: .relative).font(.system(size: 10)).foregroundStyle(.tertiary).lineLimit(1).frame(width: 65, alignment: .trailing)
                        }.padding(.vertical, 12)
                    }
                }
            }
            if !learning.historyError.isEmpty { Text(learning.historyError).font(.caption).foregroundStyle(.orange) }
            Text(tr("最近 40 次取词保存在这台 Mac 上；点击星标加入生词本。", "The last 40 lookups stay on this Mac. Star a word to add it to your vocabulary.")).font(.system(size: 10)).foregroundStyle(.tertiary)
        }
    }
    private func metric(_ title: String, _ value: Int, _ subtitle: String) -> some View {
        Paper {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("\(value)").font(.system(size: 32, weight: .semibold)).monospacedDigit()
                    Text(title).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }
}
struct SaveWordButton: View {
    let explanation: WordExplanation
    let target: String
    @ObservedObject var store: LearningStore
    var compact = false
    var body: some View {
        Button {
            if let word = store.saved(explanation, target: target) { store.remove(word.id) }
            else { store.add(explanation, target: target) }
        } label: { Image(systemName: store.saved(explanation, target: target) == nil ? "star" : "star.fill").frame(width: compact ? 24 : nil, height: compact ? 24 : nil).contentShape(Rectangle()) }
        .buttonStyle(.plain).foregroundStyle(.secondary).help("收藏 / 移除 · Save / Remove")
    }
}
struct VocabularyPage: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var learning: LearningStore
    let controller: AppController
    @State private var query = ""
    @State private var language = ""
    @State private var state = "all"
    @State private var newest = true
    @State private var exportMessage = ""
    private func tr(_ zh: String, _ en: String) -> String { settings.tr(zh, en) }
    private var filtered: [VocabularyWord] {
        learning.words.filter {
            (query.isEmpty || ($0.explanation.word + " " + $0.explanation.meaning).localizedCaseInsensitiveContains(query)) &&
            (language.isEmpty || $0.explanation.language == language) &&
            (state == "all" || (state == "due" && !$0.schedule.suspended && $0.schedule.due <= Date()) ||
             (state == "mastered" && $0.schedule.mastered) || (state == "paused" && $0.schedule.suspended) ||
             (state == "learning" && !$0.schedule.mastered && !$0.schedule.suspended))
        }.sorted { newest ? $0.createdAt > $1.createdAt : $0.createdAt < $1.createdAt }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            HStack {
                VStack(alignment: .leading, spacing: 9) {
                    Text(tr("生词本", "Vocabulary")).font(.system(size: 29, weight: .semibold))
                    Text(tr("把一时的陌生，变成长期的熟悉。", "Keep the words you want to know.")).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Menu(tr("导出", "Export")) {
                    Button("CSV") { export(.csv) }
                    Button(tr("Anki 牌组", "Anki deck")) { export(.anki) }
                    Button(tr("不背单词 / 纯文本", "Word list / Plain text")) { export(.text) }
                }.fixedSize().disabled(filtered.isEmpty)
            }
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(tr("搜索单词或释义", "Search words or meanings"), text: $query).textFieldStyle(.plain)
            }.padding(11).background(Palette.card, in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.stroke))
            HStack(spacing: 14) {
                Picker(tr("语言", "Language"), selection: $language) {
                    Text(tr("全部语言", "All languages")).tag("")
                    ForEach(Array(Set(learning.words.map { $0.explanation.language })).sorted().filter { !$0.isEmpty }, id: \.self) { Text($0.uppercased()).tag($0) }
                }.labelsHidden()
                Picker(tr("状态", "State"), selection: $state) {
                    Text(tr("全部状态", "All states")).tag("all"); Text(tr("待复习", "Due")).tag("due")
                    Text(tr("学习中", "Learning")).tag("learning"); Text(tr("已掌握", "Mastered")).tag("mastered"); Text(tr("已暂停", "Paused")).tag("paused")
                }.labelsHidden()
                Spacer()
                Button { newest.toggle() } label: { Label(newest ? tr("最新收藏", "Newest first") : tr("最早收藏", "Oldest first"), systemImage: "arrow.up.arrow.down") }.buttonStyle(.plain).font(.system(size: 11)).fixedSize()
            }
            if learning.canUndo { Button(tr("撤销移除", "Undo removal")) { learning.undo() }.buttonStyle(QuietButton()) }
            if !exportMessage.isEmpty { Text(exportMessage).font(.caption).foregroundStyle(.secondary) }
            if filtered.isEmpty {
                if learning.words.isEmpty {
                    empty(tr("这里还没有单词", "No words here yet"), tr("在翻译浮窗点击星标，即可保存释义和语境。", "Star a result to save its definition and context."))
                } else {
                    empty(tr("没有匹配的单词", "No matching words"), tr("试试其他关键词，或调整语言和学习状态。", "Try another search, language, or learning state."))
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(filtered) { word in
                        VStack(alignment: .leading, spacing: 13) {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Button { controller.showEntry(word.explanation, target: word.target) } label: {
                                Text(word.explanation.word).font(.system(size: 19, weight: .semibold))
                            }.buttonStyle(.plain)
                            Button { controller.speak(word.explanation) } label: { Image(systemName: "speaker.wave.2") }.buttonStyle(.plain).foregroundStyle(.secondary)
                            Spacer()
                            Text(word.createdAt, format: .dateTime.month().day()).font(.system(size: 10)).foregroundStyle(.tertiary)
                            Menu {
                                Button(word.schedule.suspended ? tr("恢复学习", "Resume learning") : tr("停止学习", "Pause learning")) { learning.suspend(word.id, value: !word.schedule.suspended) }
                                Button(tr("移除", "Remove")) { learning.remove(word.id) }
                            } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 22)
                            }
                            HStack(spacing: 9) {
                                if !word.explanation.phonetic.isEmpty { Text(word.explanation.phonetic) }
                                Text(word.explanation.partOfSpeech)
                                Text(languageName(word.explanation.language, settings: settings))
                                if word.schedule.suspended { Text(tr("已暂停", "Paused")) }
                            }.font(.system(size: 11)).foregroundStyle(.secondary)
                            Text(word.explanation.meaning).font(.system(size: 14)).textSelection(.enabled)
                            let sentence = word.explanation.context.isEmpty ? word.explanation.example : word.explanation.context
                            let translation = word.explanation.context.isEmpty ? word.explanation.exampleTranslation : word.explanation.contextTranslation
                            if !sentence.isEmpty {
                                VStack(alignment: .leading, spacing: 7) {
                                    HighlightedSentence(sentence: sentence, word: word.explanation.word).font(.system(size: 12)).lineSpacing(4)
                                    if !translation.isEmpty { Text(translation).font(.system(size: 12)).lineSpacing(3) }
                                }.foregroundStyle(.secondary).textSelection(.enabled)
                                    .padding(.leading, 13).overlay(alignment: .leading) { Rectangle().fill(Palette.stroke).frame(width: 2) }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 23)
                        Divider()
                    }
                }
            }
        }
    }
    private func export(_ format: VocabularyFormat) {
        do { if try VocabularyExporter.save(filtered, format: format) { exportMessage = tr("已导出当前筛选结果。", "Exported the current selection.") } }
        catch { exportMessage = error.localizedDescription }
    }
}
func empty(_ title: String, _ subtitle: String) -> some View {
    VStack(spacing: 12) {
        Image(systemName: "book.closed").font(.system(size: 30, weight: .light)).foregroundStyle(.tertiary)
        Text(title).font(.system(size: 16, weight: .medium))
        Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
    }.frame(maxWidth: .infinity).padding(.vertical, 56)
}
struct ReviewPage: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var learning: LearningStore
    let controller: AppController
    @State private var revealed = false
    @State private var reviewed = 0
    private func tr(_ zh: String, _ en: String) -> String { settings.tr(zh, en) }
    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            Text(tr("温故，知新。", "Make it familiar.")).font(.system(size: 29, weight: .semibold))
            Text(tr("还剩 \(learning.due.count) 个词 · 本次已复习 \(reviewed) 个", "\(learning.due.count) words due · \(reviewed) reviewed this session")).foregroundStyle(.secondary).font(.system(size: 12))
            if let word = learning.due.first {
                Paper {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack {
                            Text(word.explanation.word).font(.system(size: 30, weight: .semibold)); Spacer()
                            Button { controller.speak(word.explanation) } label: { Image(systemName: "speaker.wave.2") }.buttonStyle(.plain)
                        }
                        Text(word.explanation.phonetic).foregroundStyle(.secondary)
                        let sentence = word.explanation.context.isEmpty ? word.explanation.example : word.explanation.context
                        if !sentence.isEmpty { HighlightedSentence(sentence: sentence, word: word.explanation.word).font(.system(size: 14)).foregroundStyle(.secondary).lineSpacing(5) }
                        if revealed {
                            Divider()
                            Text(word.explanation.meaning).font(.system(size: 19, weight: .medium)).textSelection(.enabled)
                            let translation = word.explanation.context.isEmpty ? word.explanation.exampleTranslation : word.explanation.contextTranslation
                            if !translation.isEmpty { Text(translation).font(.system(size: 12)).foregroundStyle(.secondary) }
                            HStack(spacing: 8) {
                                gradeButton(.again, word, tr("忘记", "Again"))
                                gradeButton(.hard, word, tr("困难", "Hard"))
                                gradeButton(.good, word, tr("记得", "Good"))
                                gradeButton(.easy, word, tr("熟悉", "Easy"))
                            }.padding(.top, 8)
                        } else {
                            Button(tr("显示释义", "Show answer")) { revealed = true }.buttonStyle(QuietButton()).keyboardShortcut(.space, modifiers: [])
                        }
                    }.padding(.vertical, 12)
                }
                Button(tr("暂时停止学习这个词", "Pause learning this word")) { if learning.suspend(word.id, value: true) { revealed = false } }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
            } else {
                empty(tr("今天的复习完成了", "You are all caught up"), tr("下次到期时，单词会重新出现在这里。", "Words return here when the next review is due."))
            }
        }.onChange(of: learning.due.first?.id) { _, _ in revealed = false }
    }
    private func gradeButton(_ grade: ReviewGrade, _ word: VocabularyWord, _ label: String) -> some View {
        var schedule = word.schedule
        schedule.review(grade)
        let days = schedule.intervalDays
        let interval = days < 1 ? tr("10 分钟", "10 min") : tr("\(Int(days.rounded())) 天", "\(Int(days.rounded())) days")
        return Button {
            if learning.review(word.id, grade: grade) { revealed = false; reviewed += 1 }
        } label: {
            VStack(spacing: 5) { Text(label); Text(interval).font(.system(size: 10)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity)
        }.buttonStyle(QuietButton())
    }
}
struct QuickInputView: View {
    @ObservedObject var settings: AppSettings
    let translate: (String) -> Void
    @State private var text = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(settings.tr("想翻译什么？", "What would you like to translate?")).font(.system(size: 21, weight: .semibold))
            InputEditor(text: $text, submit: submit).padding(10).background(Palette.card, in: RoundedRectangle(cornerRadius: 9)).overlay(RoundedRectangle(cornerRadius: 9).stroke(Palette.stroke))
            HStack {
                Text(settings.tr("Return 翻译 · Shift + Return 换行", "Return to translate · Shift + Return for a new line")).font(.caption).foregroundStyle(.secondary); Spacer()
                Button(settings.tr("翻译", "Translate"), action: submit).keyboardShortcut(.return, modifiers: .command).buttonStyle(QuietButton()).disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 12000)
            }
        }.padding(24).background(Palette.background)
    }
    private func submit() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.count <= 12000 else { NSSound.beep(); return }
        translate(text)
    }
}

struct InputEditor: NSViewRepresentable {
    @Binding var text: String
    var submit: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        let view = InputTextView()
        view.delegate = context.coordinator; view.isRichText = false; view.font = .systemFont(ofSize: 16)
        view.textColor = .labelColor; view.drawsBackground = false; view.isVerticallyResizable = true
        view.textContainerInset = CGSize(width: 3, height: 5)
        view.textContainer?.widthTracksTextView = true; view.autoresizingMask = [.width]
        view.submit = submit; scroll.documentView = view; scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        return scroll
    }
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        if let view = nsView.documentView as? InputTextView {
            if view.string != text { view.string = text }
            view.submit = submit
        }
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: InputEditor
        init(_ parent: InputEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            if let view = notification.object as? NSTextView { parent.text = view.string }
        }
    }
}
final class InputTextView: NSTextView {
    var submit: (() -> Void)?
    override func keyDown(with event: NSEvent) {
        // Let an input method confirm its composition before handling Return.
        if [36, 76].contains(Int(event.keyCode)), !hasMarkedText(), !event.modifierFlags.contains(.shift) {
            submit?(); return
        }
        super.keyDown(with: event)
    }
}
