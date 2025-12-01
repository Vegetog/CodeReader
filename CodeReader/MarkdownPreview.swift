import SwiftUI

struct MarkdownPreview: View {
    let text: String
    let fontSize: CGFloat

    var body: some View {
        MarkdownWebView(markdown: text, fontSize: fontSize)
            .edgesIgnoringSafeArea(.bottom)
    }
}
