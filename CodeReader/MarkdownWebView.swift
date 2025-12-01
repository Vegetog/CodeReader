import SwiftUI
import WebKit

struct MarkdownWebView: UIViewRepresentable {
    let markdown: String
    let fontSize: CGFloat

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.showsHorizontalScrollIndicator = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = buildHTML(from: markdown, fontSize: fontSize)
        webView.loadHTMLString(html, baseURL: nil)
    }

    // MARK: - HTML 模板

    private func buildHTML(from markdown: String, fontSize: CGFloat) -> String {
        // 用 Base64 传输 markdown，避免引号转义各种麻烦
        let data = Data(markdown.utf8)
        let base64 = data.base64EncodedString()

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <meta charset="utf-8">

            <!-- highlight.js 代码高亮 -->
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css">
            <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>

            <!-- markdown-it 核心 -->
            <script src="https://cdn.jsdelivr.net/npm/markdown-it@13.0.1/dist/markdown-it.min.js"></script>
            <script src="https://cdn.jsdelivr.net/npm/markdown-it-container@3.0.0/dist/markdown-it-container.min.js"></script>

            <!-- KaTeX 数学公式 -->
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
            <script src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>
            <script src="https://cdn.jsdelivr.net/npm/markdown-it-katex@3.0.1/dist/markdown-it-katex.min.js"></script>

            <style>
                :root {
                    color-scheme: light dark;
                }

                body {
                    margin: 0;
                    padding: 16px;
                    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, -apple-system-body;
                    font-size: \(fontSize)px;
                    line-height: 1.6;
                    color: #e6e6e6;
                    background-color: transparent;
                    -webkit-text-size-adjust: 100%;
                }

                h1, h2, h3, h4, h5, h6 {
                    font-weight: 600;
                    margin-top: 1.2em;
                    margin-bottom: 0.6em;
                }

                h1 { font-size: \(fontSize * 1.8)px; }
                h2 { font-size: \(fontSize * 1.6)px; }
                h3 { font-size: \(fontSize * 1.4)px; }
                h4 { font-size: \(fontSize * 1.2)px; }

                code {
                    font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
                    background-color: rgba(255, 255, 255, 0.06);
                    padding: 2px 4px;
                    border-radius: 4px;
                }

                pre {
                    background-color: rgba(0, 0, 0, 0.4);
                    padding: 12px;
                    border-radius: 8px;
                    overflow-x: auto;
                }

                pre code {
                    background: none;
                    padding: 0;
                }

                a {
                    color: #4aa3ff;
                    text-decoration: none;
                }

                a:hover {
                    text-decoration: underline;
                }

                blockquote {
                    border-left: 4px solid rgba(255, 255, 255, 0.25);
                    padding-left: 12px;
                    margin-left: 0;
                    color: rgba(255, 255, 255, 0.8);
                }

                table {
                    border-collapse: collapse;
                    width: 100%;
                    margin: 12px 0;
                }

                table th, table td {
                    border: 1px solid rgba(255, 255, 255, 0.2);
                    padding: 6px 8px;
                }

                img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 6px;
                }

                ul, ol {
                    padding-left: 1.4em;
                }

                hr {
                    border: 0;
                    border-top: 1px solid rgba(255, 255, 255, 0.2);
                    margin: 16px 0;
                }
            </style>
        </head>
        <body>
            <div id="content"></div>

            <script>
                (function() {
                    var md = window.markdownit({
                        html: true,
                        linkify: true,
                        breaks: true,
                        highlight: function (str, lang) {
                            try {
                                return '<pre><code class="hljs">' +
                                    hljs.highlight(str, {language: lang || 'plaintext'}).value +
                                    '</code></pre>';
                            } catch (__) {}
                            return '<pre><code class="hljs">' + md.utils.escapeHtml(str) + '</code></pre>';
                        }
                    })
                    .use(window.markdownitKatex);

                    // Base64 解码 markdown
                    var base64 = "\(base64)";
                    var decoded = decodeURIComponent(escape(window.atob(base64)));

                    document.getElementById('content').innerHTML = md.render(decoded);
                })();
            </script>
        </body>
        </html>
        """

        return html
    }
}
