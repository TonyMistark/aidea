# Aidear

把你的零散想法变成结构完整、排版精美的公众号文章。

## 这是什么

Aidear 是一款 iOS AI 写作助手。你只需要写下碎片想法，AI 会自动扩展成一篇标题、摘要、正文、封面图提示词齐全的文章。生成的正文可直接复制为微信格式 HTML，粘贴到公众号编辑器即用。

## 核心功能

- **AI 生成文章** — 从关键词、短句生成结构完整的文章（标题 / 摘要 / 正文 / 封面图提示词）
- **直接 Markdown 转换** — 已有 Markdown 文本可直接粘贴转换，无需调用 AI，即时渲染微信排版预览
- **智能布局切换** — 生成/转换完成后输入区自动折叠至顶部，文章内容占据主视觉区域，阅读体验优先
- **微信排版渲染** — 使用 [md2wechat](https://github.com/liuliqiu/md2wechat) 的 CSS 主题，在 App 内预览微信排版效果
- **一键复制** — 摘要和正文均支持一键复制，正文复制带完整样式的 HTML，粘贴到公众号编辑器样式不丢
- **支持自定义 AI 后端** — 兼容 OpenAI API 格式，可配置自定义 endpoint 和模型
- **自定义 AI Prompt** — 在设置页查看和编辑 AI system prompt，自由定制文章生成风格
- **AI 生成可取消** — 生成过程中点击按钮可取消（二次确认），避免误操作浪费 token
- **生成计时器** — AI 生成按钮实时显示已用秒数，直观感知生成耗时

## 技术栈

| 层 | 技术 |
|---|---|
| UI | SwiftUI (iOS 17.0+) |
| Markdown → HTML | marked.js + highlight.js (WKWebView) |
| 微信排版 CSS | md2wechat default 主题 |
| AI 服务 | OpenAI API 兼容接口 |

## 项目结构

```
aidear/
├── aidearApp.swift              # App 入口
├── Models/
│   └── AppSettings.swift        # 配置持久化
├── Services/
│   └── GenerationService.swift  # AI 生成逻辑
├── Views/
│   ├── ContentView.swift        # 主界面
│   ├── MarkdownWebView.swift    # 微信排版 WebView
│   └── SettingsView.swift       # 设置页
└── Assets.xcassets/
docs/                            # App Store 上架文档
```

## 开始开发

```bash
# 1. 克隆
git clone git@github.com:TonyMistark/aidea.git
cd aidear

# 2. 用 Xcode 打开
open aidear.xcodeproj

# 3. 选择 iOS Simulator，Run (⌘R)
```

App 内置了模拟数据，不配置 API Key 也能完整体验生成流程。配置 API Key 后在 Settings 页填入即可直连 OpenAI 兼容服务。

在 Settings 页底部还可查看和编辑 **AI System Prompt**，支持自定义写作指令、输出格式等，修改保存后对所有新生成生效。

> **注意**：当前版本 API Key 存于本地。发布到 App Store 前需要搭建后端代理，详见 `docs/backend-proxy.md`。

## App Store 上架

上架前需要完成的工作已整理在 `docs/` 目录：

- [总清单](docs/app-store-launch-checklist.md)
- [后端代理方案](docs/backend-proxy.md)
- [Sign in with Apple](docs/sign-in-with-apple.md)
- [素材与元数据](docs/app-store-materials.md)
- [隐私政策与合规](docs/privacy-and-compliance.md)

## 许可

MIT
