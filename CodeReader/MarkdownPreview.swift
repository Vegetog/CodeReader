import SwiftUI

struct MarkdownPreview: View {
    let text: String
    let fontSize: CGFloat
    let scrollTargetHeadingID: String?

    var body: some View {
        MarkdownWebView(
            markdown: text,
            fontSize: fontSize,
            scrollTargetHeadingID: scrollTargetHeadingID
        )
            .edgesIgnoringSafeArea(.bottom)
    }
}
