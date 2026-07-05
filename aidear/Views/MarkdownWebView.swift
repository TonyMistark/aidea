import SwiftUI
import UIKit
import WebKit

// MARK: - highlight.js default theme CSS (inline, matches Pygments default style)

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

private func makeHTMLOutline(themeCSS: String) -> String {
    """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <style>
    \(themeCSS)
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
    var _loadedThemeCSS = null;

    function renderMarkdown(md, themeCSS) {
        if (themeCSS && themeCSS !== _loadedThemeCSS) {
            _loadedThemeCSS = themeCSS;
            var styleEl = document.getElementById('aidear-theme-css');
            if (!styleEl) {
                styleEl = document.createElement('style');
                styleEl.id = 'aidear-theme-css';
                document.head.appendChild(styleEl);
            }
            styleEl.textContent = themeCSS;
        }
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

    (function poll() {
        if (_queued && typeof marked !== 'undefined') {
            doRender(_queued);
            _queued = null;
        }
        if (_queued) setTimeout(poll, 80);
    })();

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

    function getCopyContent() {
        var el = document.getElementById('aidear-content');
        window.webkit.messageHandlers.copyContent.postMessage(JSON.stringify({
            html: el.innerHTML,
            text: el.innerText
        }));
    }

    document.addEventListener('DOMContentLoaded', function() {});
    </script>
    </body>
    </html>
    """
}

// MARK: - SwiftUI Wrapper

struct MarkdownWebView: UIViewRepresentable {
    let markdown: String
    var themeID: String = "wechat-green"
    var onHeightChange: ((CGFloat) -> Void)?
    var copyTrigger: Int = 0
    
    private var themeCSS: String {
        ThemeManager.shared.themes.first(where: { $0.id == themeID })?.cssStyles
            ?? Theme.wechatGreen.cssStyles
    }

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
        webView.loadHTMLString(makeHTMLOutline(themeCSS: themeCSS), baseURL: URL(string: "https://aidear.app/"))

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Handle markdown rendering + theme switching
        context.coordinator.pendingMarkdown = markdown
        context.coordinator.pendingThemeID = themeID
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
        var pendingThemeID: String?
        var lastRendered: String?
        var lastRenderedThemeID: String?
        var lastCopyTrigger: Int = 0
        var pageLoaded = false
        var onHeightChange: ((CGFloat) -> Void)?

        init(onHeightChange: ((CGFloat) -> Void)?) {
            self.onHeightChange = onHeightChange
        }

        func renderIfReady() {
            guard pageLoaded, let webView, let md = pendingMarkdown,
                  md != lastRendered || pendingThemeID != lastRenderedThemeID else { return }
            lastRendered = md
            lastRenderedThemeID = pendingThemeID

            let themeCSS = ThemeManager.shared.themes
                .first(where: { $0.id == pendingThemeID })?
                .cssStyles ?? Theme.wechatGreen.cssStyles

            guard let jsonData = try? JSONEncoder().encode(md),
                  let jsonString = String(data: jsonData, encoding: .utf8) else { return }
            guard let cssData = try? JSONEncoder().encode(themeCSS),
                  let cssString = String(data: cssData, encoding: .utf8) else { return }

            // First set the theme CSS, then render markdown
            webView.evaluateJavaScript("renderMarkdown(\(jsonString), \(cssString))", completionHandler: nil)
        }

        func requestCopyHTML() {
            webView?.evaluateJavaScript("copyFormatted()") { [weak self] result, _ in
                if let success = result as? Bool, success {
                    return // execCommand('copy') succeeded, WebKit handles pasteboard
                }
                // Fallback: get HTML + text manually
                self?.webView?.evaluateJavaScript("getCopyContent()") { _, _ in
                    // Ignore fallback — execCommand should work
                }
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
