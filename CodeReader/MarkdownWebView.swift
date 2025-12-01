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
        // 把 markdown 转成适合放进 JS 模板字符串的形式
        let escaped = markdown
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "</script>", with: "<\\/script>")

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <meta charset="utf-8">

            <!-- highlight.js 代码高亮（可选） -->
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css">
            <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>

            <!-- markdown-it 核心 -->
            <script src="https://cdn.jsdelivr.net/npm/markdown-it@13.0.1/dist/markdown-it.min.js"></script>

            <style>
                :root {
                    color-scheme: light;
                }

                body {
                    margin: 0;
                    padding: 16px;
                    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, -apple-system-body;
                    font-size: \(fontSize)px;
                    line-height: 1.6;
                    color: #000000;
                    background-color: #FFFFFF;
                    -webkit-text-size-adjust: 100%;
                }

                h1, h2, h3, h4, h5, h6 {
                    font-weight: 600;
                    margin-top: 1.2em;
                    margin-bottom: 0.6em;
                    color: #000000;
                }

                h1 { font-size: \(fontSize * 1.8)px; }
                h2 { font-size: \(fontSize * 1.6)px; }
                h3 { font-size: \(fontSize * 1.4)px; }
                h4 { font-size: \(fontSize * 1.2)px; }

                code {
                    font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
                    background-color: rgba(0, 0, 0, 0.06);
                    padding: 2px 4px;
                    border-radius: 4px;
                    color: #000000;
                }

                pre {
                    background-color: rgba(0, 0, 0, 0.05);
                    padding: 12px;
                    border-radius: 8px;
                    overflow-x: auto;
                }

                pre code {
                    background: none;
                    padding: 0;
                }

                a {
                    color: #007AFF;
                    text-decoration: none;
                }

                a:hover {
                    text-decoration: underline;
                }

                blockquote {
                    border-left: 4px solid rgba(0, 0, 0, 0.25);
                    padding-left: 12px;
                    margin-left: 0;
                    color: rgba(0, 0, 0, 0.8);
                }

                table {
                    border-collapse: collapse;
                    width: 100%;
                    margin: 12px 0;
                }

                table th, table td {
                    border: 1px solid rgba(0, 0, 0, 0.2);
                    padding: 6px 8px;
                    color: #000000;
                }

                img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 6px;
                    display: block;
                    margin: 8px 0;
                }

                ul, ol {
                    padding-left: 1.4em;
                }

                hr {
                    border: 0;
                    border-top: 1px solid rgba(0, 0, 0, 0.2);
                    margin: 16px 0;
                }
            </style>
        </head>
        <body>
            <div id="content"></div>

            <script>
                (function() {
                    // Swift 注入的原始 markdown 文本（已经在 Swift 里做了转义）
                    var decoded = `\(escaped)`;

                    // markdown-it 没加载成功：直接显示原始 markdown 文本
                    if (!window.markdownit) {
                        var el = document.getElementById('content');
                        el.innerText = decoded || 'markdown-it 加载失败';
                        return;
                    }

                    var md = window.markdownit({
                        html: true,
                        linkify: true,
                        breaks: true,
                        highlight: function (str, lang) {
                            try {
                                if (lang && window.hljs) {
                                    return '<pre><code class="hljs">' +
                                        window.hljs.highlight(str, {language: lang}).value +
                                        '</code></pre>';
                                }
                            } catch (e) {}
                            return '<pre><code class="hljs">' + md.utils.escapeHtml(str) + '</code></pre>';
                        }
                    });

                    document.getElementById('content').innerHTML = md.render(decoded);
                })();
            </script>
        </body>
        </html>
        """

        return html
    }
}
