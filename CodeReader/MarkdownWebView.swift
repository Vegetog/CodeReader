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
        // 1. 继续使用 Base64 传输，这是最稳妥的方案，防止反斜杠丢失
        let base64String = markdown.data(using: .utf8)?.base64EncodedString() ?? ""

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <meta charset="utf-8">

            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/atom-one-light.min.css" media="(prefers-color-scheme: light)">
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/atom-one-dark.min.css" media="(prefers-color-scheme: dark)">
            <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>

            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
            <script src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>

            <script src="https://cdn.jsdelivr.net/npm/markdown-it@13.0.1/dist/markdown-it.min.js"></script>

            <script src="https://cdn.jsdelivr.net/npm/markdown-it-texmath@1.0.0/texmath.min.js"></script>

            <style>
                :root { color-scheme: light dark; }
                
                body {
                    margin: 0;
                    padding: 16px;
                    /* 使用系统字体栈，接近原生体验 */
                    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    font-size: \(fontSize)px;
                    line-height: 1.6;
                    color: var(--text-color);
                    background-color: var(--background-color);
                    -webkit-text-size-adjust: 100%;
                }

                /* 优化公式字体大小，避免公式过小 */
                .katex { font-size: 1.1em; }
                
                /* 你的其他样式保持不变 */
                h1, h2, h3, h4, h5, h6 { font-weight: 600; margin-top: 1.2em; margin-bottom: 0.6em; color: var(--text-color); }
                h1 { font-size: \(fontSize * 1.8)px; }
                h2 { font-size: \(fontSize * 1.6)px; }
                code { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; background-color: var(--inline-code-bg); padding: 2px 4px; border-radius: 4px; color: var(--text-color); }
                pre { background-color: var(--pre-bg); padding: 12px; border-radius: 8px; overflow-x: auto; }
                pre code { background: none; padding: 0; }
                img { max-width: 100%; height: auto; border-radius: 6px; display: block; margin: 8px 0; }
                table { border-collapse: collapse; width: 100%; margin: 12px 0; }
                table th, table td { border: 1px solid var(--table-border); padding: 6px 8px; }
                blockquote { border-left: 4px solid var(--quote-border); padding-left: 12px; margin-left: 0; color: var(--quote-text); }

                :root[data-theme="light"] {
                    --text-color: #383a42; --background-color: #fafafa;
                    --inline-code-bg: #ebebeb; --pre-bg: #f6f8fa;
                    --link-color: #4078f2; --quote-border: rgba(0,0,0,0.2); --quote-text: rgba(0,0,0,0.8);
                    --table-border: rgba(0,0,0,0.2);
                }
                :root[data-theme="dark"] {
                    --text-color: #abb2bf; --background-color: #1f2229;
                    --inline-code-bg: #282c34; --pre-bg: #282c34;
                    --link-color: #61afef; --quote-border: rgba(255,255,255,0.25); --quote-text: rgba(255,255,255,0.85);
                    --table-border: rgba(255,255,255,0.25);
                }
            </style>
        </head>
        <body>
            <div id="content"></div>

            <script>
                (function() {
                    // 主题适配
                    var prefersDark = window.matchMedia('(prefers-color-scheme: dark)');
                    var setTheme = function(isDark) { document.documentElement.setAttribute('data-theme', isDark ? 'dark' : 'light'); };
                    setTheme(prefersDark.matches);
                    prefersDark.addEventListener('change', function(e) { setTheme(e.matches); });

                    // 1. 解码 Base64
                    var rawBase64 = "\(base64String)";
                    var decodedMarkdown = "";
                    try {
                        decodedMarkdown = decodeURIComponent(escape(window.atob(rawBase64)));
                    } catch(e) {
                        console.error("Base64 error", e);
                        decodedMarkdown = "Content loading error";
                    }

                    // 2. 初始化 markdown-it
                    if (window.markdownit) {
                        var md = window.markdownit({
                            html: true,
                            linkify: true,
                            breaks: true,
                            highlight: function (str, lang) {
                                if (lang && window.hljs) {
                                    try { return '<pre><code class="hljs">' + window.hljs.highlight(str, {language: lang}).value + '</code></pre>'; } catch (__) {}
                                }
                                return '<pre><code class="hljs">' + md.utils.escapeHtml(str) + '</code></pre>';
                            }
                        });

                        // 3. 【核心配置】模拟 VS Code 的数学公式渲染
                        // 使用 texmath 插件，并指定 engine 为 katex
                        // delimiters: 'dollars' 意思是允许 $...$ 和 $$...$$
                        if (typeof texmath !== 'undefined' && window.katex) {
                            md.use(texmath, {
                                engine: window.katex,
                                delimiters: 'dollars',
                                katexOptions: { macros: { "\\\\RR": "\\\\mathbb{R}" } } // 可选：添加常用宏
                            });
                        }

                        document.getElementById('content').innerHTML = md.render(decodedMarkdown);
                    } else {
                        document.getElementById('content').innerText = decodedMarkdown;
                    }
                })();
            </script>
        </body>
        </html>
        """
        return html
    }
}
