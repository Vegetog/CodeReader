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

            <!-- highlight.js 代码高亮 -->
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/atom-one-light.min.css" media="(prefers-color-scheme: light)">
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/atom-one-dark.min.css" media="(prefers-color-scheme: dark)">
            <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>

            <!-- markdown-it 核心 -->
            <script src="https://cdn.jsdelivr.net/npm/markdown-it@13.0.1/dist/markdown-it.min.js"></script>

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
                    color: var(--text-color);
                    background-color: var(--background-color);
                    -webkit-text-size-adjust: 100%;
                    transition: color 0.2s ease, background-color 0.2s ease;
                }

                h1, h2, h3, h4, h5, h6 {
                    font-weight: 600;
                    margin-top: 1.2em;
                    margin-bottom: 0.6em;
                    color: var(--text-color);
                }

                h1 { font-size: \(fontSize * 1.8)px; }
                h2 { font-size: \(fontSize * 1.6)px; }
                h3 { font-size: \(fontSize * 1.4)px; }
                h4 { font-size: \(fontSize * 1.2)px; }

                code {
                    font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
                    background-color: var(--inline-code-bg);
                    padding: 2px 4px;
                    border-radius: 4px;
                    color: var(--text-color);
                }

                pre {
                    background-color: var(--pre-bg);
                    padding: 12px;
                    border-radius: 8px;
                    overflow-x: auto;
                }

                pre code {
                    background: none;
                    padding: 0;
                }

                a {
                    color: var(--link-color);
                    text-decoration: none;
                }

                a:hover {
                    text-decoration: underline;
                }

                blockquote {
                    border-left: 4px solid var(--quote-border);
                    padding-left: 12px;
                    margin-left: 0;
                    color: var(--quote-text);
                }

                table {
                    border-collapse: collapse;
                    width: 100%;
                    margin: 12px 0;
                }

                table th, table td {
                    border: 1px solid var(--table-border);
                    padding: 6px 8px;
                    color: var(--text-color);
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
                    border-top: 1px solid var(--table-border);
                    margin: 16px 0;
                }

                :root[data-theme="light"] {
                    --text-color: #383a42;
                    --background-color: #fafafa;
                    --inline-code-bg: #ebebeb;
                    --pre-bg: #f6f8fa;
                    --link-color: #4078f2;
                    --quote-border: rgba(0, 0, 0, 0.2);
                    --quote-text: rgba(0, 0, 0, 0.8);
                    --table-border: rgba(0, 0, 0, 0.2);
                }

                :root[data-theme="dark"] {
                    --text-color: #abb2bf;
                    --background-color: #1f2229;
                    --inline-code-bg: #282c34;
                    --pre-bg: #282c34;
                    --link-color: #61afef;
                    --quote-border: rgba(255, 255, 255, 0.25);
                    --quote-text: rgba(255, 255, 255, 0.85);
                    --table-border: rgba(255, 255, 255, 0.25);
                }
            </style>
        </head>
        <body>
            <div id="content"></div>

            <script>
                (function() {
                    var prefersDark = window.matchMedia('(prefers-color-scheme: dark)');
                    var setTheme = function(isDark) {
                        document.documentElement.setAttribute('data-theme', isDark ? 'dark' : 'light');
                    };
                    setTheme(prefersDark.matches);
                    prefersDark.addEventListener('change', function(event) { setTheme(event.matches); });

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
