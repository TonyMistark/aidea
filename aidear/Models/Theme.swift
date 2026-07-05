import Foundation

// MARK: - Theme

struct Theme: Identifiable, Equatable {
    let id: String          // e.g., "wechat-green", "doocs-default"
    let name: String        // Display name
    let description: String
    let previewColors: (primary: String, secondary: String)
    
    var cssStyles: String
    
    static func == (lhs: Theme, rhs: Theme) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Theme Manager

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var activeThemeID: String {
        didSet { UserDefaults.standard.set(activeThemeID, forKey: "active_theme_id") }
    }
    
    @Published var themes: [Theme] = []
    
    private init() {
        let savedID = UserDefaults.standard.string(forKey: "active_theme_id") ?? "wechat-green"
        
        // Validate against known themes (hardcoded to avoid circular dependency)
        switch savedID {
        case "wechat-green", "doocs-default", "doocs-grace", "doocs-simple":
            self.activeThemeID = savedID
        default:
            self.activeThemeID = "wechat-green"
        }
        self.themes = Self.builtInThemes
    }
    
    var activeTheme: Theme {
        themes.first(where: { $0.id == activeThemeID }) ?? themes[0]
    }
    
    func setTheme(id: String) {
        guard themes.contains(where: { $0.id == id }) else { return }
        activeThemeID = id
    }
    
    // MARK: - Built-in Themes
    
    static let builtInThemes: [Theme] = [
        .wechatGreen,
        .defaultTheme,
        .graceTheme,
        .simpleTheme
    ]
}

// MARK: - Theme Extensions for Each Built-in Theme

extension Theme {
    // MARK: WeChat Green (current default)
    static let wechatGreen = Theme(
        id: "wechat-green",
        name: "微信绿",
        description: "经典绿色调，适合公众号文章",
        previewColors: ("#07c160", "#f5f5f5"),
        cssStyles: """
body {
    font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", "PingFang SC",
                 "Hiragino Sans GB", "Microsoft YaHei UI", "Microsoft YaHei", Arial, sans-serif;
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
    font-size: 24px; font-weight: 700; color: #1a1a1a;
    margin: 32px 0 16px; padding-bottom: 12px;
    border-bottom: 2px solid #07c160; line-height: 1.4;
}
h2 {
    font-size: 20px; font-weight: 600; color: #1a1a1a;
    margin: 28px 0 12px; padding-left: 12px;
    border-left: 4px solid #07c160; line-height: 1.4;
}
h3 {
    font-size: 18px; font-weight: 600; color: #2c2c2c;
    margin: 24px 0 10px; line-height: 1.4;
}
h4 {
    font-size: 16px; font-weight: 600; color: #444444;
    margin: 20px 0 8px;
}
p { margin: 12px 0; text-align: justify; }
strong { font-weight: 700; color: #07c160; }
em { font-style: italic; color: #555555; }
a { color: #576b95; text-decoration: none; border-bottom: 1px solid #576b95; }
ul, ol { padding-left: 24px; margin: 12px 0; }
li { margin: 6px 0; line-height: 1.8; }
blockquote {
    margin: 16px 0; padding: 12px 16px;
    border-left: 4px solid #07c160;
    background-color: #f7f7f7; color: #666666; font-size: 15px;
}
code {
    font-family: "SF Mono", Menlo, Monaco, Consolas, "Courier New", monospace;
    font-size: 0.9em; background-color: #f5f5f5; padding: 2px 6px;
    border-radius: 4px; color: #e83e8c;
}
pre {
    margin: 16px 0; padding: 16px; background-color: #f8f8f8;
    border-radius: 8px; overflow-x: auto; font-size: 14px; line-height: 1.6;
    -webkit-overflow-scrolling: touch;
}
pre code { background: none; padding: 0; color: #333333; font-size: inherit; }
img { max-width: 100%; height: auto; display: block; margin: 16px auto; border-radius: 6px; }
hr { border: none; border-top: 1px solid #e0e0e0; margin: 24px 0; }
table {
    width: 100%; border-collapse: collapse; margin: 16px 0; font-size: 14px;
    display: block; overflow-x: auto; -webkit-overflow-scrolling: touch;
}
th, td { border: 1px solid #e0e0e0; padding: 10px 12px; text-align: left; }
th { background-color: #f7f7f7; font-weight: 600; color: #333333; }
tr:nth-child(even) { background-color: #fafafa; }
"""
    )
    
    // MARK: Doocs Default (classic)
    static let defaultTheme = Theme(
        id: "doocs-default",
        name: "经典",
        description: "完整排版主题，覆盖所有元素",
        previewColors: ("#2196f3", "#e3f2fd"),
        cssStyles: """
/* ----md2all start---- */
*{box-sizing:border-box;margin:0;padding:0;}
html,body,section,ol,ul,h1,h2,h3,h4,h5,h6,p,pre,dl,dd,form,blockquote,th,td,hr,button,
figure,figcaption,figcaption{margin:0;padding:0;}
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Oxygen,Ubuntu,Cantarell,
"Open Sans","Helvetica Neue",Arial,sans-serif;font-size:16px;line-height:1.75;color:#3e474b;
word-wrap:break-word;overflow-wrap:break-word;background-color:#fff;}
section,#output .container{text-align:left;}
#output{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Oxygen,Ubuntu,Cantarell,
"Open Sans","Helvetica Neue",Arial,sans-serif;font-size:16px;line-height:1.75;text-align:left;}
#output section>:first-child,#section>:first-child{margin-top:0!important;}
blockquote,section blockquote{margin-left:0;margin-right:0;margin-top:0;}
table,#output table,section table{border-collapse:collapse;min-width:100%;}
.mermaid-diagram .nodeLabel p{color:unset!important;letter-spacing:unset!important;}
/* Container */
section,.container{max-width:100%;padding:0 10px;}
/* Typography */
h1{font-size:24px;font-weight:700;color:#111;margin:24px 0 16px;padding-bottom:10px;
border-bottom:2px solid #2196f3;line-height:1.4;}
h2{font-size:20px;font-weight:600;color:#222;margin:24px 0 12px;padding-left:10px;
border-left:4px solid #2196f3;line-height:1.4;}
h3{font-size:18px;font-weight:600;color:#333;margin:20px 0 10px;line-height:1.4;}
h4{font-size:16px;font-weight:600;color:#444;margin:16px 0 8px;}
p{margin:12px 0;text-align:justify;line-height:1.75;}
strong,b{font-weight:700;color:#2196f3;}
em,i{font-style:italic;color:#555;}
a{color:#1976d2;text-decoration:none;border-bottom:1px dashed #1976d2;}
a:hover{color:#0d47a1;}
/* Lists */
ul,ol{padding-left:24px;margin:12px 0;}
ul ul,ul ol,ol ul,ol ol{margin:4px 0;}
li{margin:4px 0;line-height:1.75;}
li>p{margin:4px 0;}
/* Blockquote */
blockquote{margin:16px 0;padding:12px 16px;border-left:4px solid #2196f3;
background-color:#e3f2fd;color:#555;font-size:15px;}
blockquote>p{margin:0;}
/* Code */
code{font-family:"SF Mono",Menlo,Monaco,Consolas,"Courier New",monospace;font-size:0.9em;
background-color:#f5f5f5;padding:2px 6px;border-radius:4px;color:#e83e8c;}
pre{margin:16px 0;padding:16px;background-color:#f8f8f8;border-radius:8px;
overflow-x:auto;font-size:14px;line-height:1.6;}
pre code{background:none;padding:0;color:#333;font-size:inherit;}
/* Images */
img{max-width:100%;height:auto;display:block;margin:16px auto;border-radius:6px;}
/* Horizontal rule */
hr{border:none;border-top:1px solid #e0e0e0;margin:24px 0;}
/* Tables */
table{width:100%;border-collapse:collapse;margin:16px 0;font-size:14px;
display:block;overflow-x:auto;-webkit-overflow-scrolling:touch;}
th,td{border:1px solid #ddd;padding:10px 12px;text-align:left;}
th{background-color:#f5f5f5;font-weight:600;color:#333;}
tr:nth-child(even){background-color:#fafafa;}
/* Alerts / Callouts */
.alert{margin:16px 0;padding:12px 16px;border-radius:4px;border-left:4px solid;}
.alert-info{background-color:#e3f2fd;border-color:#2196f3;color:#1565c0;}
.alert-success{background-color:#e8f5e9;border-color:#4caf50;color:#2e7d32;}
.alert-warning{background-color:#fff3e0;border-color:#ff9800;color:#e65100;}
.alert-danger{background-color:#ffebee;border-color:#f44336;color:#c62828;}
/* MathJax placeholder */
.math-block{text-align:center;margin:16px 0;padding:12px;background-color:#fafafa;border-radius:4px;}
/* Footnotes */
.footnotes{margin-top:32px;padding-top:16px;border-top:1px solid #e0e0e0;font-size:14px;}
.footnotes ol{padding-left:20px;}
.footnotes li{margin:4px 0;}
/* Definition List */
dl{margin:12px 0;}
dt{font-weight:700;margin:8px 0 4px;}
dd{margin-left:20px;margin-bottom:8px;}
/* Kbd key */
kbd{font-family:monospace;font-size:0.85em;background:#eee;border:1px solid #ccc;
border-radius:3px;padding:1px 4px;}
/* ----md2all end---- */
"""
    )
    
    // MARK: Doocs Grace (elegant)
    static let graceTheme = Theme(
        id: "doocs-grace",
        name: "优雅",
        description: "圆角阴影优雅风格",
        previewColors: ("#9c27b0", "#f3e5f5"),
        cssStyles: """
/* Grace theme — elegant rounded style */
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Oxygen,Ubuntu,Cantarell,
"Open Sans","Helvetica Neue",Arial,sans-serif;font-size:16px;line-height:1.75;color:#333;
word-wrap:break-word;overflow-wrap:break-word;background:#fdfdfd;padding:20px 16px;}
h1{font-size:24px;font-weight:700;color:#333;margin:30px 0 16px;text-align:center;
padding-bottom:12px;border-bottom:2px solid #e0e0e0;}
h2{font-size:20px;font-weight:600;color:#444;margin:24px 0 12px;
padding-left:14px;border-left:4px solid #9c27b0;border-radius:0 8px 8px 0;}
h3{font-size:18px;font-weight:600;color:#555;margin:20px 0 10px;}
h4{font-size:16px;font-weight:600;color:#666;margin:16px 0 8px;}
p{margin:12px 0;text-align:justify;line-height:1.75;}
strong{font-weight:700;color:#9c27b0;}
em{font-style:italic;color:#666;}
a{color:#9c27b0;text-decoration:none;border-bottom:1px dashed #9c27b0;}
a:hover{color:#7b1fa2;}
ul,ol{padding-left:24px;margin:12px 0;}
li{margin:6px 0;line-height:1.75;}
blockquote{margin:16px 0;padding:14px 18px;border-left:4px solid #e1bee7;
background:linear-gradient(to right,#fce4ec,#fff);border-radius:8px;
color:#555;font-size:15px;box-shadow:0 2px 4px rgba(0,0,0,0.05);}
blockquote>p{margin:0;}
code{font-family:"SF Mono",Menlo,Monaco,Consolas,"Courier New",monospace;
font-size:0.9em;background-color:#f5f0f5;padding:2px 6px;border-radius:4px;color:#9c27b0;}
pre{margin:16px 0;padding:16px;background:#faf7fa;border-radius:10px;
overflow-x:auto;font-size:14px;line-height:1.6;
box-shadow:inset 0 1px 3px rgba(0,0,0,0.06);}
pre code{background:none;padding:0;color:#444;font-size:inherit;}
img{max-width:100%;height:auto;display:block;margin:16px auto;border-radius:12px;
box-shadow:0 4px 12px rgba(0,0,0,0.1);}
hr{border:none;border-top:1px solid #e0e0e0;margin:24px 0;border-radius:2px;}
table{width:100%;border-collapse:collapse;margin:16px 0;font-size:14px;
display:block;overflow-x:auto;-webkit-overflow-scrolling:touch;}
th,td{border:1px solid #e0e0e0;padding:10px 12px;text-align:left;}
th{background:linear-gradient(135deg,#ede7f6,#f3e5f5);font-weight:600;color:#4a148c;}
tr:nth-child(even){background-color:#fafafa;}
tr:hover{background-color:#f5f0fa;}
.alert{margin:16px 0;padding:14px 18px;border-radius:8px;border-left:4px solid;}
.alert-info{background:#f3e5f5;border-color:#9c27b0;color:#4a148c;}
.alert-success{background:#e8f5e9;border-color:#66bb6a;color:#2e7d32;}
.alert-warning{background:#fff8e1;border-color:#ffa726;color:#e65100;}
.alert-danger{background:#ffebee;border-color:#ef5350;color:#c62828;}
dl{margin:12px 0;}
dt{font-weight:700;margin:8px 0 4px;color:#9c27b0;}
dd{margin-left:20px;margin-bottom:8px;}
.footnotes{margin-top:32px;padding-top:16px;border-top:2px dashed #e0e0e0;
font-size:14px;color:#777;}
.footnotes ol{padding-left:20px;}
.footnotes li{margin:6px 0;}
.kbd{font-family:monospace;font-size:0.85em;background:#f5f0f5;border:1px solid #e0e0e0;
border-radius:6px;padding:2px 6px;}
"""
    )
    
    // MARK: Doocs Simple (minimal)
    static let simpleTheme = Theme(
        id: "doocs-simple",
        name: "简洁",
        description: "极简现代风格，适合技术文档",
        previewColors: ("#424242", "#fafafa"),
        cssStyles: """
/* Simple theme — minimal modern style */
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Oxygen,Ubuntu,Cantarell,
"Open Sans","Helvetica Neue",Arial,sans-serif;font-size:16px;line-height:1.65;color:#212121;
word-wrap:break-word;overflow-wrap:break-word;background:#fff;padding:20px 16px;margin:0;}
h1{font-size:24px;font-weight:600;color:#212121;margin:28px 0 14px;border-bottom:1px solid #e0e0e0;
padding-bottom:10px;letter-spacing:-0.3px;}
h2{font-size:20px;font-weight:600;color:#424242;margin:24px 0 12px;}
h3{font-size:18px;font-weight:600;color:#616161;margin:20px 0 10px;}
h4{font-size:16px;font-weight:500;color:#757575;margin:16px 0 8px;}
p{margin:10px 0;text-align:justify;line-height:1.65;}
strong{font-weight:600;color:#212121;}
em{font-style:italic;color:#616161;}
a{color:#1565c0;text-decoration:none;}
a:hover{text-decoration:underline;}
a:visited{color:#7b1fa2;}
ul,ol{padding-left:24px;margin:10px 0;}
li{margin:4px 0;line-height:1.65;}
li>p{margin:4px 0;}
blockquote{margin:14px 0;padding:10px 16px;border-left:3px solid #bdbdbd;
background:#fafafa;color:#616161;font-size:15px;}
blockquote>p{margin:0;}
code{font-family:"SF Mono",Menlo,Monaco,Consolas,"Courier New",monospace;
font-size:0.88em;background:#f5f5f5;padding:1px 5px;border-radius:3px;color:#c62828;}
pre{margin:14px 0;padding:14px;background:#fafafa;border-radius:6px;
overflow-x:auto;font-size:13.5px;line-height:1.55;border:1px solid #e0e0e0;}
pre code{background:none;padding:0;color:#333;font-size:inherit;}
img{max-width:100%;height:auto;display:block;margin:14px auto;}
hr{border:none;border-top:1px solid #e0e0e0;margin:20px 0;}
table{width:100%;border-collapse:collapse;margin:14px 0;font-size:14px;
display:block;overflow-x:auto;-webkit-overflow-scrolling:touch;}
th,td{border:1px solid #e0e0e0;padding:9px 11px;text-align:left;}
th{background:#f5f5f5;font-weight:600;color:#424242;}
tr:nth-child(even){background:#fafafa;}
dl{margin:10px 0;}
dt{font-weight:600;margin:6px 0 3px;}
dd{margin-left:18px;margin-bottom:6px;}
.footnotes{margin-top:28px;padding-top:14px;border-top:1px solid #e0e0e0;
font-size:13.5px;color:#757575;}
.footnotes ol{padding-left:18px;}
.footnotes li{margin:4px 0;}
.alert{margin:14px 0;padding:10px 14px;border-left:3px solid;border-radius:4px;font-size:14px;}
.alert-info{background:#f5f5f5;border-color:#9e9e9e;color:#616161;}
.alert-success{background:#e8f5e9;border-color:#66bb6a;color:#2e7d32;}
.alert-warning{background:#fff8e1;border-color:#ffa726;color:#e65100;}
.alert-danger{background:#ffebee;border-color:#ef5350;color:#c62828;}
.kbd{font-family:monospace;font-size:0.85em;background:#f5f5f5;border:1px solid #e0e0e0;
border-radius:3px;padding:1px 4px;color:#616161;}
"""
    )
}
