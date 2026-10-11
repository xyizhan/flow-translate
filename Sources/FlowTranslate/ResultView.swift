import AppKit
import SwiftUI
import Translation

struct ResultView: View {
    @ObservedObject var model: TranslationModel
    @ObservedObject var learning: LearningStore
    @ObservedObject var voice: Pronunciation
    @ObservedObject var preferences: AppSettings
    let close: () -> Void
    let pin: () -> Void
    let openSettings: () -> Void
    var contentHeightChanged: (CGFloat) -> Void = { _ in }
    @State private var copied = false
    @Environment(\.colorScheme) private var colorScheme
    private var palette: ReadingPalette { ReadingPalette(dark: colorScheme == .dark) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                content.fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(GeometryReader { geometry in
                        Color.clear.preference(key: ResultContentHeight.self, value: geometry.size.height)
                    })
            }.scrollIndicators(.automatic)
            footer
        }
        .foregroundStyle(palette.ink).tint(palette.accent)
        .background(ReadingSurface(palette: palette))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(palette.edge.opacity(0.65), lineWidth: 0.5))
        .onPreferenceChange(ResultContentHeight.self) { height in if height > 0 { contentHeightChanged(height) } }
        .translationTask(model.appleConfiguration) { session in await model.translateWithApple(session, id: model.requestID) }
        .onChange(of: model.requestID) { _, _ in copied = false }
        .ignoresSafeArea()
    }
    private var header: some View {
        HStack(spacing: 2) {
            HStack(spacing: 6) {
                FlowMark().frame(width: 16, height: 16).foregroundStyle(palette.accent)
                Text("Flow Translate").font(.system(size: 10.5, weight: .semibold, design: .rounded)).tracking(-0.1)
                    .foregroundStyle(palette.accent).fixedSize()
            }.accessibilityElement(children: .combine)
            Spacer(minLength: 5)
            if model.busy { ProgressView().controlSize(.mini).padding(.trailing, 4) }
            if model.saveable {
                Button {
                    if let saved = learning.saved(model.entry, target: model.targetCode) { learning.remove(saved.id) }
                    else { learning.add(model.entry, target: model.targetCode) }
                } label: { Image(systemName: learning.saved(model.entry, target: model.targetCode) == nil ? "star" : "star.fill") }
                    .help(preferences.tr("收藏 / 移除", "Save / Remove"))
            }
            Button {
                NSPasteboard.general.clearContents(); NSPasteboard.general.setString(model.copyText, forType: .string); copied = true
            } label: { Image(systemName: copied ? "checkmark" : "doc.on.doc") }
                .help(preferences.tr("复制", "Copy")).disabled(model.output.isEmpty)
            Button(action: pin) { Image(systemName: model.pinned ? "pin.fill" : "pin") }
                .help(preferences.tr("固定浮窗", "Pin window"))
                .foregroundStyle(model.pinned ? palette.accent : palette.subtle)
            Button(action: close) { Image(systemName: "xmark") }.help(preferences.tr("关闭", "Close"))
        }
        .buttonStyle(ResultActionStyle(tint: palette.accent)).foregroundStyle(palette.subtle)
        .padding(.leading, 16).padding(.trailing, 10).frame(height: 38)
        .overlay(alignment: .bottom) { palette.line.opacity(0.65).frame(height: 0.5).padding(.horizontal, 16) }
    }
    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !model.source.isEmpty {
                if model.dictionary { dictionaryHeading }
                else {
                    Text(model.source).font(.system(size: 12)).foregroundStyle(palette.secondary)
                        .lineSpacing(3).textSelection(.enabled)
                }
            }
            if !model.output.isEmpty {
                Text(model.output).font(.system(size: 15, weight: model.dictionary ? .medium : .regular))
                    .lineSpacing(4).textSelection(.enabled)
            } else if model.busy {
                Text(model.phase + "…").font(.system(size: 12)).foregroundStyle(palette.secondary)
            }
            if let e = model.explanation {
                if !e.context.isEmpty { context(e.context, translation: e.contextTranslation, word: e.word, isExample: false) }
                else if !e.example.isEmpty { context(e.example, translation: e.exampleTranslation, word: e.word, isExample: true) }
            }
            if !model.error.isEmpty {
                Text(model.error).font(.system(size: 12)).foregroundStyle(palette.ink).textSelection(.enabled)
                Button(preferences.tr("打开设置", "Open settings"), action: openSettings).buttonStyle(QuietButton())
            }
            if !learning.error.isEmpty { Text(learning.error).font(.system(size: 11)).foregroundStyle(palette.secondary) }
        }
    }
    private var dictionaryHeading: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(model.source).font(.system(size: 26, weight: .medium, design: .serif)).tracking(-0.4).textSelection(.enabled)
                Button { voice.say(model.source, language: model.sourceCode, englishVoice: preferences.options.englishVoice) } label: {
                    Image(systemName: "speaker.wave.2").font(.system(size: 10)).frame(width: 25, height: 25)
                        .background(palette.context, in: Circle())
                }.buttonStyle(.plain).foregroundStyle(palette.accent).help(voice.slow ? "0.75×" : "1×")
            }
            if let e = model.explanation {
                HStack(spacing: 8) {
                    if !e.phonetic.isEmpty { Text(e.phonetic).font(.system(size: 10.5)).textSelection(.enabled) }
                    Text([e.partOfSpeech, languageName(e.language, settings: preferences)].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 9.5)).textSelection(.enabled)
                }.foregroundStyle(palette.secondary)
                if !e.expansion.isEmpty { Text(e.expansion).font(.system(size: 11)).foregroundStyle(palette.secondary).textSelection(.enabled) }
            }
        }
    }
    private func context(_ sentence: String, translation: String, word: String, isExample: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "text.quote").font(.system(size: 9))
                Text(isExample ? preferences.tr("例句", "EXAMPLE") : preferences.tr("语境", "IN CONTEXT"))
                    .font(.system(size: 8.5, weight: .medium)).tracking(0.8)
            }.foregroundStyle(palette.accent.opacity(0.85)).padding(.bottom, 1)
            HighlightedSentence(sentence: sentence, word: word, highlightColor: palette.accent, highlightBackground: .clear)
                .foregroundStyle(palette.ink).textSelection(.enabled)
            if !translation.isEmpty { Text(translation).foregroundStyle(palette.secondary).textSelection(.enabled) }
        }
        .font(.system(size: 11.5)).lineSpacing(2)
        .padding(.horizontal, 11).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.context, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
    private var footer: some View {
        HStack(spacing: 5) {
            Circle().fill(model.error.isEmpty ? palette.accent.opacity(0.65) : Color.orange).frame(width: 3, height: 3)
            Text(model.busy ? model.phase : model.mode).lineLimit(1)
            Spacer(minLength: 4)
            if model.busy {
                Button(preferences.tr("取消", "Cancel")) { model.cancel() }.buttonStyle(.plain)
            } else if !model.error.isEmpty {
                Text(preferences.tr("需要处理", "Needs attention"))
            } else if model.isExample {
                Text(preferences.tr("界面示例", "Preview"))
            } else if model.elapsed == 0 {
                Text(model.phase).lineLimit(1)
            } else {
                Text(model.fromCache ? preferences.tr("已缓存", "Cached") : String(format: "%.2f s", model.elapsed)).monospacedDigit()
            }
        }.font(.system(size: 9)).foregroundStyle(palette.subtle).padding(.horizontal, 16).frame(height: 26)
    }
}
