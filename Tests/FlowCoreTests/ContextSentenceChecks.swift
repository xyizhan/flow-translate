import Foundation
import FlowCore

enum ContextSentenceChecks {
    static func run() {
        func line(_ text: String, _ y: CGFloat, x: CGFloat = 50, width: CGFloat = 500, height: CGFloat = 20) -> TextLine {
            TextLine(text: text, rect: CGRect(x: x, y: y, width: width, height: height))
        }
        func check(_ lines: [TextLine], anchor: Int, word: String, expected: String, last: Bool = false) {
            let item = lines[anchor]
            let range = (item.text as NSString).range(of: word, options: last ? .backwards : [])
            let result = ContextSentence.extract(anchor: item, wordRange: range, lines: lines)
            precondition(result == expected, "Context for \(word): expected [\(expected)], got [\(result)]")
        }
        let sentence = "The bank was covered with wild flowers."
        let screen = [line("TextEdit File Edit Format View Window Help", 0, x: 10, height: 13),
                      line("2 4 6 8 10 12 14 16", 28), line(sentence, 60),
                      line("Fast translation keeps you in the flow.", 90),
                      line("Select a region of the screen and translate it.", 120)]
        check(screen, anchor: 2, word: "with", expected: sentence)
        check(screen, anchor: 3, word: "flow", expected: screen[3].text)
        let wrapped = [line("An unrelated sentence. The bank was", 0),
                       line("covered with wild flowers along", 30),
                       line("the river. We went home.", 60)]
        for (index, word) in [(0, "bank"), (1, "with"), (2, "river")] {
            check(wrapped, anchor: index, word: word, expected: "The bank was covered with wild flowers along the river.")
        }
        check([line("We went to the bank. The river bank was green.", 0)], anchor: 0, word: "bank", expected: "The river bank was green.", last: true)
        check([line("Dr. Smith paid $3.50 for it. Next sentence.", 0)], anchor: 0, word: "Smith", expected: "Dr. Smith paid $3.50 for it.")
        check([line("We use tools, e.g. a pen, every day. Stop.", 0)], anchor: 0, word: "pen", expected: "We use tools, e.g. a pen, every day.")
        check([line("这是第一句。河岸开满了鲜花！你看到了吗？", 0)], anchor: 0, word: "鲜花", expected: "河岸开满了鲜花！")
        check([line("これは前の文です。川岸には", 0), line("花が咲いています。次の文です。", 30)], anchor: 1, word: "花", expected: "川岸には花が咲いています。")
        check([line("The bank was covered with", 0), line("A different column must stay out.", 28, x: 700),
               line("wild flowers.", 30)], anchor: 2, word: "flowers", expected: sentence)
        check([line("An unfinished paragraph", 0), line("The target has no punctuation", 80)], anchor: 1, word: "target", expected: "The target has no punctuation")
        check([line("Title", 0, width: 50), line(sentence, 30)], anchor: 1, word: "bank", expected: sentence)
        check([line("A state-of-the-", 0), line("art tool is useful. Another sentence.", 30)], anchor: 1, word: "tool", expected: "A state-of-the-art tool is useful.")
        print("CONTEXT PASS: sentence boundaries, clicked occurrence, wrapped lines, menus/rulers, columns, paragraphs, abbreviations, CJK")
    }
}
