import Foundation
import UIKit

/// 将剪贴板中的富文本转换为 Markdown。
final class RichTextParser {

    // MARK: - Public API

    static func parseClipboardAsMarkdown() -> String? {
        let pb = UIPasteboard.general

        // 1. HTML — most common path
        if let htmlData = pb.data(forPasteboardType: "public.html"),
           let htmlString = String(data: htmlData, encoding: .utf8),
           htmlString.count > 3 {
            return convertHTML(htmlString)
        }

        // 2. RTF fallback
        if let rtfData = pb.data(forPasteboardType: "public.rtf") {
            do {
                let attrStr = try NSAttributedString(
                    data: rtfData,
                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
                )
                let plain = attrStr.string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !plain.isEmpty, plain.count > 3 {
                    return attrStrToMD(attrStr)
                }
            } catch {}
        }

        return nil
    }

    // MARK: - Tokenizer

    enum Token {
        case text(String)
        case tagOpen(String)   // <h1, <p, <li, <blockquote, <ul, <ol, <table, <tr, <td, <th
        case tagClose(String)  // </p, </h1, </table, </tr, </td
        case hr               // <hr
        case br               // <br
        case img(src: String) // <img src="..."
        case blank            // just whitespace/empty
    }

    private struct ParseResult {
        var markdown = ""
        var inBlockquote = false
        var listStack: [ListKind] = []
        var needsSeparator = false
        
        // Table state
        var inTable = false
        var tableRows: [[String]] = []
        var inHeaderRow = false
    }

    private enum ListKind { case ordered, unordered }

    // MARK: - Main Conversion

    private static func convertHTML(_ html: String) -> String {
        // Strip scripts/styles/comments/wrappers
        var h = html
        
        // 1. Remove WeChat editor specific wrappers and styles
        h = stripWeChatEditorStyles(h)
        
        // 2. Standard cleanup
        h = h.replacingOccurrences(of: "<style[^>]*>.*?</style>", with: "", options: .regularExpression)
        h = h.replacingOccurrences(of: "<script[^>]*>.*?</script>", with: "", options: .regularExpression)
        let commentPattern = "(?:<!--|//[^\"]*?)-->"
        h = h.replacingOccurrences(of: commentPattern, with: "", options: .regularExpression)
        h = h.replacingOccurrences(of: "<body[^>]*>|</body>|<!DOCTYPE|<html[^>]*>|</html>",
                                     with: "", options: .regularExpression)
        // Remove style/class/id attributes but preserve closing /> on self-closing tags
        h = h.replacingOccurrences(of: "(<[a-z][a-z0-9]*)\\s+[^>]*/?>", with: "$1>", options: .regularExpression)

        let tokens = tokenize(h)
        var ctx = ParseResult()

        for tok in tokens {
            process(&ctx, token: tok)
        }

        // Flush any pending heading prefix
        flushPendingHeadingPrefix(&ctx)

        return normalize(ctx.markdown)
    }

    /// Strip WeChat editor specific HTML artifacts
    private static func stripWeChatEditorStyles(_ html: String) -> String {
        var result = html
        
        // Remove WeChat editor-specific class names
        let wechatClasses = [
            "msg_content", "rich_media_area_primary", "rich_media_tool",
            "activity-detail", "js_name", "rich_media_content",
            "showswiftpic", "original-content", "wechat-single-item"
        ]
        for className in wechatClasses {
            result = result.replacingOccurrences(
                of: "\\bclass=[\"'][^\"']*\\(className)[^\"\"]*[\"']",
                with: "", options: .regularExpression
            )
        }
        
        // Remove WeChat-specific inline styles (font-family, color, etc.)
        result = result.replacingOccurrences(
            of: "style=[\"']font-family:[^;]+;[^\"]*[\"']",
            with: "", options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "style=[\"']color:[^;]+;[^\"]*[\"']",
            with: "", options: .regularExpression
        )
        
        // Normalize WeChat's special line breaks (often uses <br><br> or <p><br></p>)
        result = result.replacingOccurrences(
            of: "<br\\s*/?>\\s*<br\\s*/?>",
            with: "\n\n", options: .regularExpression
        )
        
        // Remove empty paragraphs that WeChat often generates
        result = result.replacingOccurrences(
            of: "<p><br\\s*/?></p>",
            with: "", options: .regularExpression
        )
        
        return result
    }

    private static func process(_ ctx: inout ParseResult, token: Token) {
        switch token {
        case .text(let s):
            handleText(&ctx, text: s)

        case .tagOpen(let name):
            if name.hasPrefix("table") {
                handleTableOpen(&ctx)
            } else if name.hasPrefix("tr") {
                handleRowOpen(&ctx)
            } else if name.hasPrefix("th") || name.hasPrefix("td") {
                handleCellOpen(&ctx, isHeader: name.hasPrefix("th"))
            } else {
                handleTagOpen(&ctx, tag: name)
            }

        case .tagClose(let name):
            if name.hasPrefix("table") {
                handleTableClose(&ctx)
            } else if name.hasPrefix("tr") {
                handleRowClose(&ctx)
            } else if name.hasPrefix("th") || name.hasPrefix("td") {
                handleCellClose(&ctx)
            } else {
                handleTagClose(&ctx, tag: name)
            }

        case .hr:
            handleHR(&ctx)

        case .br:
            handleBR(&ctx)

        case .img(let src):
            handleIMG(&ctx, src: src)

        case .blank:
            break
        }
    }

    // MARK: - Token Emission Handlers

    private static func handleText(_ ctx: inout ParseResult, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Inline formatting
        let processed = applyInlineFormat(trimmed)
        // Decode HTML entities
        let final = decodeEntities(processed)

        if ctx.inTable, !ctx.tableRows.isEmpty {
            // Add to current cell
            ctx.tableRows[ctx.tableRows.count - 1].append(final)
            return
        }

        if ctx.inBlockquote {
            appendIfNeeded(&ctx.markdown)
            ctx.markdown += "> \(final)\n"
        } else if !ctx.listStack.isEmpty {
            // Inside a list
            appendIfNeeded(&ctx.markdown)
            let marker = ctx.listStack.last == .ordered ? "1. " : "- "
            ctx.markdown += "\(marker)\(final)\n"
        } else {
            // Regular paragraph / heading continuation
            // Don't add \n\n here — it's just text content
            if ctx.needsSeparator {
                ctx.markdown += "---\n\n"
                ctx.needsSeparator = false
            }
            // Check if there's a pending heading prefix
            if let (_, _) = findPendingHeadingPrefix(ctx.markdown) {
                // We're still building a heading — just append space + text
                ctx.markdown += " " + final
            } else {
                // Normal paragraph text
                appendIfNeeded(&ctx.markdown)
                ctx.markdown += final + "\n"
            }
        }
    }

    private static func handleTagOpen(_ ctx: inout ParseResult, tag: String) {
        switch tag {
        case "h1":
            startHeading(&ctx, hashes: 1)
        case "h2":
            startHeading(&ctx, hashes: 2)
        case "h3":
            startHeading(&ctx, hashes: 3)
        case "h4":
            startHeading(&ctx, hashes: 4)
        case "h5":
            startHeading(&ctx, hashes: 5)
        case "h6":
            startHeading(&ctx, hashes: 6)
        case "p", "div", "section", "article":
            finalizePendingHeading(&ctx)
            ctx.needsSeparator = true
        case "blockquote":
            finalizePendingHeading(&ctx)
            ctx.inBlockquote = true
            ctx.needsSeparator = true
        case "ul":
            finalizePendingHeading(&ctx)
            ctx.listStack.append(.unordered)
        case "ol":
            finalizePendingHeading(&ctx)
            ctx.listStack.append(.ordered)
        default:
            break
        }
    }

    private static func handleTagClose(_ ctx: inout ParseResult, tag: String) {
        switch tag {
        case "h1", "h2", "h3", "h4", "h5", "h6":
            // Heading ends naturally when we see its closing tag
            // Text will be appended after the hashes
            break
        case "p", "div", "section", "article":
            // Paragraph ended
            break
        case "blockquote":
            ctx.inBlockquote = false
            ctx.markdown += "\n"
        case "ul":
            ctx.listStack.removeAll { $0 == .unordered }
        case "ol":
            ctx.listStack.removeAll { $0 == .ordered }
        case "li":
            // LI end doesn't need special handling; newline already added
            break
        default:
            break
        }
    }

    private static func handleHR(_ ctx: inout ParseResult) {
        finalizePendingHeading(&ctx)
        ctx.markdown += "---\n\n"
        ctx.needsSeparator = false
    }

    private static func handleBR(_ ctx: inout ParseResult) {
        if ctx.inBlockquote || !ctx.listStack.isEmpty {
            // In a block/list, just skip BR
        } else {
            ctx.markdown += "<br>\n"
        }
    }

    private static func handleIMG(_ ctx: inout ParseResult, src: String) {
        // Skip images for now (or could output ![alt](src))
    }

    // MARK: - Table helpers

    private static func handleTableOpen(_ ctx: inout ParseResult) {
        finalizePendingHeading(&ctx)
        ctx.inTable = true
        ctx.tableRows = []
        ctx.inHeaderRow = false
        ctx.needsSeparator = true
    }

    private static func handleRowOpen(_ ctx: inout ParseResult) {
        if ctx.inTable {
            ctx.tableRows.append([])
            // First row is treated as header
            ctx.inHeaderRow = ctx.tableRows.count == 1
        }
    }

    private static func handleCellOpen(_ ctx: inout ParseResult, isHeader: Bool) {
        if ctx.inTable, !ctx.tableRows.isEmpty {
            // Cell content will be accumulated in text handler
        }
    }

    private static func handleCellClose(_ ctx: inout ParseResult) {
        // Cell content already added via text handler
    }

    private static func handleRowClose(_ ctx: inout ParseResult) {
        if ctx.inTable, !ctx.tableRows.isEmpty {
            let lastRow = ctx.tableRows.removeLast()
            if ctx.inHeaderRow {
                // Add separator after first row (header)
                ctx.tableRows.append(lastRow)
                ctx.tableRows.append(Array(repeating: "---", count: lastRow.count))
                ctx.inHeaderRow = false
            } else {
                ctx.tableRows.append(lastRow)
            }
        }
    }

    private static func handleTableClose(_ ctx: inout ParseResult) {
        if ctx.inTable, !ctx.tableRows.isEmpty {
            // Convert rows to Markdown table
            let mdTable = convertToMarkdownTable(ctx.tableRows)
            ctx.markdown += mdTable + "\n\n"
            ctx.tableRows = []
            ctx.inTable = false
            ctx.inHeaderRow = false
            ctx.needsSeparator = false
        }
    }

    /// Convert table rows to Markdown table format
    private static func convertToMarkdownTable(_ rows: [[String]]) -> String {
        guard !rows.isEmpty else { return "" }
        
        var result = ""
        for (i, row) in rows.enumerated() {
            let cells = row.map { $0.trimmingCharacters(in: .whitespaces) }
            result += "| " + cells.joined(separator: " | ") + " |\n"
            
            // Add separator after first row (header)
            if i == 0 && rows.count > 1 {
                result += "|" + cells.map { _ in "-----" }.joined(separator: "|") + "|\n"
            }
        }
        return result
    }

    // MARK: - Heading helpers

    /// Detects if there's a pending heading prefix (e.g., "# ", "## ") at the end of markdown
    private static func findPendingHeadingPrefix(_ md: String) -> (hashes: Int, spaceAfterHashes: Bool)? {
        let trimLen = md.trimmingCharacters(in: .whitespaces).count
        guard trimLen > 0 else { return nil }
        let lastChars = md.suffix(min(3, trimLen)).lowercased()
        // Need trailing space to know it's a heading (not part of normal text)
        guard lastChars.hasSuffix("# ") else { return nil }
        let hashCount = String(lastChars.prefix { $0 == "#" }).count
        return (hashCount, true)
    }

    private static func startHeading(_ ctx: inout ParseResult, hashes: Int) {
        finalizePendingHeading(&ctx)
        let hashStr = String(repeating: "#", count: hashes)
        ctx.markdown += hashStr + " "
    }

    private static func finalizePendingHeading(_ ctx: inout ParseResult) {
        if let (hashes, _) = findPendingHeadingPrefix(ctx.markdown) {
            // If we have a heading prefix but no content yet, discard it
            let prefixLen = hashes + 1
            let trimLen = ctx.markdown.trimmingCharacters(in: .whitespaces).count
            if trimLen <= prefixLen {
                // The heading prefix is all that's there — remove it
                ctx.markdown = ""
            }
        }
    }

    private static func flushPendingHeadingPrefix(_ ctx: inout ParseResult) {
        finalizePendingHeading(&ctx)
        // Clean up trailing whitespace on heading prefix if exists
        if let (hashes, _) = findPendingHeadingPrefix(ctx.markdown) {
            let prefixLen = hashes + 1
            let trimLen = ctx.markdown.trimmingCharacters(in: .whitespaces).count
            if trimLen <= prefixLen {
                ctx.markdown = String(ctx.markdown.dropLast(prefixLen))
            }
        }
    }

    // MARK: - String helpers

    private static func appendIfNeeded(_ md: inout String) {
        if !md.isEmpty && !md.hasSuffix("\n\n") && !md.hasSuffix("\n> ") && !md.hasSuffix("\n- ") && !md.hasSuffix("\n1. ") {
            md += "\n"
        }
    }

    private static func applyInlineFormat(_ text: String) -> String {
        var result = text
        // Bold: <b>, <strong>
        result = result.replacingOccurrences(
            of: "(?s)<(?:b|strong)>.*?</(?:b|strong)>",
            with: "**$0**", options: .regularExpression)
        // Italic: <i>, <em>
        result = result.replacingOccurrences(
            of: "(?s)<(?:i|em)>.*?</(?:i|em)>",
            with: "*$0*", options: .regularExpression)
        // Strikethrough
        result = result.replacingOccurrences(
            of: "(?s)<(?:s|del|strike)>.*?</(?:s|del|strike)>",
            with: "~~$0~~", options: .regularExpression)
        // Remove all remaining HTML tags
        result = result.replacingOccurrences(
            of: "<[^>]+>", with: "", options: .regularExpression)
        // Inline code
        result = result.replacingOccurrences(
            of: "`([^`]*)`", with: "`$1`", options: .regularExpression)
        return result
    }

    private static func decodeEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&ldquo;", with: "\"")
            .replacingOccurrences(of: "&rdquo;", with: "\"")
            .replacingOccurrences(of: "&lsquo;", with: "'")
            .replacingOccurrences(of: "&rsquo;", with: "'")
            .replacingOccurrences(of: "&mdash;", with: "—")
            .replacingOccurrences(of: "&ndash;", with: "–")
            .replacingOccurrences(of: "&bull;", with: "•")
            .replacingOccurrences(of: "&hellip;", with: "…")
            .replacingOccurrences(of: "&copy;", with: "©")
            .replacingOccurrences(of: "&reg;", with: "®")
            .replacingOccurrences(of: "&trade;", with: "™")
            .replacingOccurrences(of: "&middot;", with: "·")
    }

    private static func normalize(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Tokenizer

    private static func tokenize(_ html: String) -> [Token] {
        var tokens: [Token] = []
        var i = html.startIndex
        var textBuf = ""

        while i < html.endIndex {
            if html[i] == "<" {
                // Flush accumulated text
                if !textBuf.isEmpty {
                    let t = textBuf.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty {
                        tokens.append(.text(textBuf))
                    } else {
                        tokens.append(.blank)
                    }
                    textBuf = ""
                }

                // Find end of tag
                guard let closeRange = html[i...].firstIndex(of: ">") else {
                    textBuf.append("<")
                    i = html.index(after: i)
                    continue
                }
                let tagStr = String(html[i..<html.index(after: closeRange)])
                i = html.index(after: closeRange)

                // Classify the tag
                classifyTag(tagStr, &tokens)
            } else {
                textBuf.append(html[i])
                i = html.index(after: i)
            }
        }

        if !textBuf.isEmpty {
            let trimmed = textBuf.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                tokens.append(.text(textBuf))
            } else {
                tokens.append(.blank)
            }
        }

        return tokens
    }

    private static func classifyTag(_ tag: String, _ tokens: inout [Token]) {
        let lower = tag.lowercased()

        // Self-closing
        if tag.hasSuffix("/>") || tag.hasSuffix(" />") {
            let inner = String(tag.dropLast(2).trimmingCharacters(in: .whitespaces))
            let tagName = extractTagName(inner)
            switch tagName {
            case "img":
                if let src = getAttribute(tag, "src") {
                    tokens.append(.img(src: src))
                }
            default:
                break
            }
            return
        }

        // Close tag
        if lower.hasPrefix("</") {
            let inner = String(tag.dropFirst(2))
            let tagName = extractTagName(inner)
            tokens.append(.tagClose(tagName))
            return
        }

        // Open tag — check if it contains attribute
        let tagName = extractTagName(lower)

        switch tagName {
        case "h1", "h2", "h3", "h4", "h5", "h6":
            tokens.append(.tagOpen(tagName))
        case "p", "div", "section", "article":
            tokens.append(.tagOpen(tagName))
        case "blockquote":
            tokens.append(.tagOpen(tagName))
        case "ul", "ol":
            tokens.append(.tagOpen(tagName))
        case "li":
            tokens.append(.tagOpen(tagName))
        case "br":
            tokens.append(.br)
        case "hr":
            tokens.append(.hr)
        case "img":
            if let src = getAttribute(tag, "src") {
                tokens.append(.img(src: src))
            } else {
                tokens.append(.tagOpen("img"))
            }
        case "a":
            // Links are tricky — we handle them inline
            if let href = getAttribute(tag, "href") {
                tokens.append(.tagOpen("a[\(href)]"))
            } else {
                tokens.append(.tagOpen("a"))
            }
        case "table", "tr", "td", "th":
            tokens.append(.tagOpen(tagName))
        default:
            // Ignore unknown tags (span, font, b, strong, i, em, etc.)
            break
        }
    }

    private static func extractTagName(_ raw: String) -> String {
        var word = ""
        for c in raw {
            if c.isLetter || c.isNumber {
                word.append(c)
            } else {
                break
            }
        }
        return word.lowercased()
    }

    private static func getAttribute(_ tag: String, _ attr: String) -> String? {
        let attrEscaped = (attr as NSString).replacingOccurrences(of: "'", with: "\\'")
        let pattern = "\\b\(attrEscaped)=[\"']([^\"]*)[\"']"
        guard let range = tag.range(of: pattern, options: .regularExpression) else { return nil }
        let full = String(tag[range])
        let cleaned = full.replacingOccurrences(of: "^\\(attr)=['\"]", with: "", options: .regularExpression)
        let val = cleaned.replacingOccurrences(of: "\"$", with: "", options: .regularExpression)
        return val
    }

    // MARK: - NSAttributedString → Markdown

    private static func attrStrToMD(_ attrStr: NSAttributedString) -> String {
        let nsRange = NSRange(location: 0, length: attrStr.length)
        var paragraphs: [String] = []
        var currentRuns: [String] = []
        var indent = 0

        attrStr.enumerateAttributes(in: nsRange, options: []) { attrs, _, _ in
            let substr = (attrStr.string as NSString).substring(with: nsRange)

            if let font = attrs[.font] as? UIFont {
                let size = font.pointSize
                if !currentRuns.isEmpty {
                    let merged = currentRuns.joined().trimmingCharacters(in: .whitespaces)
                    if !merged.isEmpty { paragraphs.append(makeItems(currentRuns, indent: indent)); currentRuns = [] }
                }
                let trimmed = substr.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                if size >= 26 { paragraphs.append("# \(trimmed)") }
                else if size >= 21 { paragraphs.append("## \(trimmed)") }
                else if size >= 17 { paragraphs.append("### \(trimmed)") }
                else { currentRuns.append(trimmed) }
                return
            }

            if let paraStyle = attrs[.paragraphStyle] as? NSParagraphStyle,
               paraStyle.headIndent > 20 {
                if !currentRuns.isEmpty { paragraphs.append(makeItems(currentRuns, indent: indent)); currentRuns = [] }
                indent = max(Int(paraStyle.headIndent / 20.0) - 1, 0)
                paragraphs.append("> \(substr)")
                return
            }

            var styled = substr
            if let font = attrs[.font] as? UIFont {
                let traits = font.fontDescriptor.symbolicTraits
                if traits.contains(.traitBold) { styled = "**\(styled)**" }
                if traits.contains(.traitItalic) { styled = "*\(styled)*" }
            }
            if attrs[.strikethroughStyle] != nil { styled = "~~\(styled)~~" }
            if let link = attrs[.link] as? URL { styled = "[\(styled)](\(link.absoluteString))" }
            currentRuns.append(styled)
        }

        if !currentRuns.isEmpty { paragraphs.append(makeItems(currentRuns, indent: indent)) }
        return paragraphs.joined(separator: "\n\n")
    }

    private static func makeItems(_ runs: [String], indent: Int) -> String {
        let joined = runs.joined(separator: "")
        let trimmed = joined.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }
        if indent > 0 {
            return String(repeating: "  ", count: indent - 1) + "- \(trimmed)"
        }
        return trimmed
    }
}

// MARK: - Helper extension (file-scope)

private extension String {
    func firstRange(of target: String) -> Range<String.Index>? {
        self.range(of: target)
    }
}
