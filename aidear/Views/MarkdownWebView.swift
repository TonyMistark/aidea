import SwiftUI
import UIKit
import WebKit

// MARK: - md2wechat CSS (exact copy from default theme)

private let md2wechatCSS = """
body {
    font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", "PingFang SC",
                 "Hiragino Sans GB", "Microsoft YaHei UI", "Microsoft YaHei",
                 Arial, sans-serif;
    font-size: 16px;
    line-height: 1.8;
    color: #3f3f3f;
    padding: 20px 16px;
    word-wrap: break-word;
    overflow-wrap: break-word;
    background-color: #ffffff;
    margin: 0;
    -webkit-text-size-adjust: 100%;
}
h1 {
    font-size: 24px;
    font-weight: 700;
    color: #1a1a1a;
    margin: 32px 0 16px;
    padding-bottom: 12px;
    border-bottom: 2px solid #07c160;
    line-height: 1.4;
}
h2 {
    font-size: 20px;
    font-weight: 600;
    color: #1a1a1a;
    margin: 28px 0 12px;
    padding-left: 12px;
    border-left: 4px solid #07c160;
    line-height: 1.4;
}
h3 {
    font-size: 18px;
    font-weight: 600;
    color: #2c2c2c;
    margin: 24px 0 10px;
    line-height: 1.4;
}
h4 {
    font-size: 16px;
    font-weight: 600;
    color: #444444;
    margin: 20px 0 8px;
}
p {
    margin: 12px 0;
    text-align: justify;
}
strong {
    font-weight: 700;
    color: #07c160;
}
em {
    font-style: italic;
    color: #555555;
}
a {
    color: #576b95;
    text-decoration: none;
    border-bottom: 1px solid #576b95;
}
ul, ol {
    padding-left: 24px;
    margin: 12px 0;
}
li {
    margin: 6px 0;
    line-height: 1.8;
}
blockquote {
    margin: 16px 0;
    padding: 12px 16px;
    border-left: 4px solid #07c160;
    background-color: #f7f7f7;
    color: #666666;
    font-size: 15px;
}
code {
    font-family: "SF Mono", Menlo, Monaco, Consolas, "Courier New", monospace;
    font-size: 0.9em;
    background-color: #f5f5f5;
    padding: 2px 6px;
    border-radius: 4px;
    color: #e83e8c;
}
pre {
    margin: 16px 0;
    padding: 16px;
    background-color: #f8f8f8;
    border-radius: 8px;
    overflow-x: auto;
    font-size: 14px;
    line-height: 1.6;
    -webkit-overflow-scrolling: touch;
}
pre code {
    background: none;
    padding: 0;
    color: #333333;
    font-size: inherit;
}
img {
    max-width: 100%;
    height: auto;
    display: block;
    margin: 16px auto;
    border-radius: 6px;
}
hr {
    border: none;
    border-top: 1px solid #e0e0e0;
    margin: 24px 0;
}
table {
    width: 100%;
    border-collapse: collapse;
    margin: 16px 0;
    font-size: 14px;
    display: block;
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;
}
th, td {
    border: 1px solid #e0e0e0;
    padding: 10px 12px;
    text-align: left;
}
th {
    background-color: #f7f7f7;
    font-weight: 600;
    color: #333333;
}
tr:nth-child(even) {
    background-color: #fafafa;
}
"""

// highlight.js default theme CSS (inline, matches Pygments default style)
private let highlightJSCSS = """
.hljs{display:block;overflow-x:auto;padding:0.5em;background:#f8f8f8;color:#333}
.hljs-comment,.hljs-quote{color:#998;font-style:italic}
.hljs-keyword,.hljs-selector-tag,.hljs-subst{color:#333;font-weight:700}
.hljs-number,.hljs-literal,.hljs-variable,.hljs-template-variable,.hljs-tag .hljs-attr{color:#008080}
.hljs-string,.hljs-doctag{color:#d14}
.hljs-title,.hljs-section,.hljs-selector-id{color:#900;font-weight:700}
.hljs-subst{font-weight:400}
.hljs-type,.hljs-class .hljs-title{color:#458;font-weight:700}
.hljs-tag,.hljs-name,.hljs-attribute{color:#000080;font-weight:400}
.hljs-regexp,.hljs-link{color:#009926}
.hljs-symbol,.hljs-bullet{color:#990073}
.hljs-built_in,.hljs-builtin-name{color:#0086b3}
.hljs-meta{color:#999;font-weight:700}
.hljs-deletion{background:#fdd}
.hljs-addition{background:#dfd}
.hljs-emphasis{font-style:italic}
.hljs-strong{font-weight:700}
"""

// MARK: - HTML Template

private let htmlTemplate: String = {
    """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <style>
    \(md2wechatCSS)
    \(highlightJSCSS)
    </style>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/marked/12.0.0/marked.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
    </head>
    <body>
    <div id="aidear-content"></div>
    <script>
    var _queued = null;
    var _lastMd = null;

    function renderMarkdown(md) {
        if (md === _lastMd) return;
        _lastMd = md;
        if (typeof marked === 'undefined') {
            _queued = md;
            return;
        }
        doRender(md);
    }

    function doRender(md) {
        var el = document.getElementById('aidear-content');
        el.innerHTML = marked.parse(md);
        if (typeof hljs !== 'undefined') {
            el.querySelectorAll('pre code').forEach(function(b) { hljs.highlightElement(b); });
        }
        requestAnimationFrame(function() {
            window.webkit.messageHandlers.heightUpdate.postMessage(document.body.scrollHeight);
        });
    }

    // Poll until CDN scripts are loaded, then render queued content
    (function poll() {
        if (_queued && typeof marked !== 'undefined') {
            doRender(_queued);
            _queued = null;
        }
        if (_queued) setTimeout(poll, 80);
    })();

    // Select all rendered content and copy (preserves CSS formatting)
    function copyFormatted() {
        var el = document.getElementById('aidear-content');
        if (!el || !el.textContent.trim()) return false;
        var range = document.createRange();
        range.selectNodeContents(el);
        var sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
        try {
            document.execCommand('copy');
            sel.removeAllRanges();
            return true;
        } catch(e) {
            sel.removeAllRanges();
            return false;
        }
    }

    // Fallback: send HTML + plain text to Swift for manual pasteboard set
    function getCopyContent() {
        var el = document.getElementById('aidear-content');
        window.webkit.messageHandlers.copyContent.postMessage(JSON.stringify({
            html: el.innerHTML,
            text: el.innerText
        }));
    }

    document.addEventListener('DOMContentLoaded', function() {
        if (_queued) { doRender(_queued); _queued = null; }
    });
    </script>
    </body>
    </html>
    """
}()

// MARK: - SwiftUI Wrapper

struct MarkdownWebView: UIViewRepresentable {
    let markdown: String
    var onHeightChange: ((CGFloat) -> Void)?
    var copyTrigger: Int = 0

    func makeCoordinator() -> Coordinator {
        Coordinator(onHeightChange: onHeightChange)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Message handlers for JS → Swift communication
        config.userContentController.add(context.coordinator, name: "heightUpdate")
        config.userContentController.add(context.coordinator, name: "copyContent")

        // Disable zoom via user script
        let zoomScript = WKUserScript(
            source: "var m=document.createElement('meta');m.name='viewport';m.content='width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no';document.head.appendChild(m);",
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(zoomScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        context.coordinator.webView = webView
        webView.loadHTMLString(htmlTemplate, baseURL: URL(string: "https://aidear.app/"))

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Handle markdown rendering
        context.coordinator.pendingMarkdown = markdown
        context.coordinator.renderIfReady()

        // Handle copy trigger
        if copyTrigger != context.coordinator.lastCopyTrigger {
            context.coordinator.lastCopyTrigger = copyTrigger
            context.coordinator.requestCopyHTML()
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var pendingMarkdown: String?
        var lastRendered: String?
        var lastCopyTrigger: Int = 0
        var pageLoaded = false
        var onHeightChange: ((CGFloat) -> Void)?

        init(onHeightChange: ((CGFloat) -> Void)?) {
            self.onHeightChange = onHeightChange
        }

        func renderIfReady() {
            guard pageLoaded, let webView, let md = pendingMarkdown, md != lastRendered else { return }
            lastRendered = md

            guard let jsonData = try? JSONEncoder().encode(md),
                  let jsonString = String(data: jsonData, encoding: .utf8) else { return }

            webView.evaluateJavaScript("renderMarkdown(\(jsonString))", completionHandler: nil)
        }

        func requestCopyHTML() {
            webView?.evaluateJavaScript("copyFormatted()") { [weak self] result, _ in
                if let success = result as? Bool, success {
                    return // execCommand('copy') succeeded, WebKit handles pasteboard
                }
                // Fallback: get HTML + text manually
                self?.webView?.evaluateJavaScript("getCopyContent()", completionHandler: nil)
            }
        }

        private func setPasteboard(html: String, text: String) {
            guard let htmlData = html.data(using: .utf8),
                  let textData = text.data(using: .utf8) else { return }
            UIPasteboard.general.setItems([[
                "public.html": htmlData,
                "public.utf8-plain-text": textData,
            ]], options: [:])
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            pageLoaded = true
            renderIfReady()
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url,
               url.scheme == "http" || url.scheme == "https" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            if message.name == "heightUpdate", let height = message.body as? CGFloat {
                DispatchQueue.main.async { [weak self] in
                    self?.onHeightChange?(height)
                }
            }
            if message.name == "copyContent", let json = message.body as? String,
               let data = json.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String],
               let html = dict["html"], let text = dict["text"] {
                DispatchQueue.main.async { [weak self] in
                    self?.setPasteboard(html: html, text: text)
                }
            }
        }
    }
}
