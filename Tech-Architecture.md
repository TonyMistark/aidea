# Aidear 技术架构文档

---

## 1. 技术选型

### 1.1 基础技术栈

| 层级 | 技术选择 | 理由 |
|------|----------|------|
| UI 框架 | **SwiftUI** | 声明式、现代、iOS 17+ 新特性支持好、与系统动效天然融合 |
| 编程语言 | **Swift 5.10+** | Apple 生态首选 |
| 最低部署 | **iOS 17.0** | SwiftUI 成熟度高、SF Symbols 5、SwiftData 稳定 |
| 架构模式 | **MVVM + Swift Concurrency** | 清晰分层、async/await 天然适配 AI API 调用 |
| 数据持久化 | **SwiftData** | 现代替代 Core Data，原生整合 SwiftUI |
| 云同步 | **CloudKit** (via SwiftData) | Apple 生态最自然的云同步方案 |
| 依赖管理 | **Swift Package Manager** | Apple 官方，无需第三方工具 |
| 测试 | **XCTest + Swift Testing** | Apple 原生测试框架 |

### 1.2 关键 API 与技术

| 功能 | 使用的 API |
|------|------------|
| 语音识别 | `SFSpeechRecognizer`（设备端/服务端） |
| 音频录制 | `AVAudioEngine` / `AVAudioRecorder` |
| 触觉反馈 | `UIFeedbackGenerator` |
| 安全存储 | `Keychain Services` |
| 分享 | `UIActivityViewController` |
| 微信跳转 | URL Scheme（weixin://） |
| Safari 内嵌 | `SFSafariViewController` |
| Markdown 渲染 | 自研 Markdown 解析 + `AttributedString` |
| 系统素材 | `SF Symbols 5` |
| 图片导出 | `UIGraphicsImageRenderer` |

### 1.3 第三方依赖（最少化原则）

| 依赖 | 用途 | 理由 |
|------|------|------|
| （无必需的第三方 UI 库） | — | SwiftUI 原生组件已足够 |
| 可选：Markdown 解析库 | Markdown → AttributedString | 如原生方案足够则省略 |

**原则：能用系统 API 就不用第三方库。** 减少依赖风险、审核风险和包体积。

---

## 2. 项目结构

```
Aidear/
├── AidearApp.swift                    # App Entry Point
├── AppDelegate.swift                  # App Delegate（微信回调等）
│
├── Core/
│   ├── Constants.swift                # 全局常量
│   ├── AppError.swift                 # 统一错误类型
│   ├── Extensions/                    # Swift 扩展
│   │   ├── View+Extensions.swift
│   │   ├── Color+Extensions.swift
│   │   └── String+Extensions.swift
│   └── Utilities/
│       ├── HapticManager.swift        # 触觉反馈管理
│       ├── KeychainManager.swift      # Keychain 存取
│       └── WeChatManager.swift        # 微信跳转
│
├── Models/
│   ├── Article.swift                  # 文章数据模型（SwiftData）
│   ├── IdeaInput.swift                # 想法输入模型
│   ├── GenerationConfig.swift         # 生成配置模型
│   ├── ChatMessage.swift              # 对话消息模型
│   └── UserPreferences.swift         # 用户偏好（AppStorage）
│
├── Services/
│   ├── AIService/
│   │   ├── AIServiceProtocol.swift    # AI 服务协议
│   │   ├── OpenAIService.swift        # OpenAI 实现
│   │   ├── AnthropicService.swift     # Anthropic 实现
│   │   └── AIServiceFactory.swift     # 工厂：根据配置选择服务
│   ├── SpeechService.swift            # 语音识别服务
│   ├── ArticleStore.swift             # 文章 SwiftData 操作
│   ├── ExportService.swift            # 导出/分享服务
│   └── MarkdownParser.swift           # Markdown → AttributedString
│
├── ViewModels/
│   ├── HomeViewModel.swift            # 首页逻辑
│   ├── RecordingViewModel.swift       # 录音逻辑
│   ├── TextInputViewModel.swift       # 文字输入逻辑
│   ├── GenerationViewModel.swift      # AI 生成逻辑
│   ├── ArticlePreviewViewModel.swift  # 文章预览逻辑
│   ├── ArticleChatViewModel.swift     # 对话调整逻辑
│   ├── HistoryViewModel.swift         # 历史记录逻辑
│   └── SettingsViewModel.swift        # 设置逻辑
│
├── Views/
│   ├── AppTabView.swift               # Tab Bar 容器
│   │
│   ├── Onboarding/
│   │   ├── OnboardingView.swift       # 引导页容器
│   │   └── OnboardingPageView.swift   # 单页引导
│   │
│   ├── Home/
│   │   ├── HomeView.swift             # 首页容器
│   │   ├── RecordButton.swift         # 录音按钮组件
│   │   ├── WaveformAnimation.swift    # 声波动画
│   │   ├── TranscriptionPreview.swift # 转文字预览
│   │   └── RecentArticlesSection.swift# 最近文章区域
│   │
│   ├── TextInput/
│   │   ├── TextInputView.swift        # 文字输入页
│   │   └── MarkdownToolbar.swift      # Markdown 工具栏
│   │
│   ├── Generation/
│   │   ├── GenerationConfigSheet.swift# 配置底部 Sheet
│   │   ├── GeneratingView.swift       # 生成中页面
│   │   └── SparkAnimation.swift       # 粒子动画
│   │
│   ├── Article/
│   │   ├── ArticlePreviewView.swift   # 文章预览（阅读模式）
│   │   ├── ArticleEditView.swift      # 文章编辑模式
│   │   ├── TitleCarousel.swift        # 备用标题滑动选择
│   │   ├── ArticleToolbar.swift       # 底部操作栏
│   │   └── ArticleChatView.swift      # 对话调整
│   │
│   ├── History/
│   │   ├── HistoryView.swift          # 历史列表
│   │   ├── ArticleRow.swift           # 文章卡片行
│   │   ├── FilterChips.swift          # 筛选 Chips
│   │   └── HistoryEmptyView.swift     # 空态
│   │
│   ├── Settings/
│   │   ├── SettingsView.swift         # 设置列表
│   │   ├── AIConfigView.swift         # AI 配置详情
│   │   ├── APIKeyField.swift          # API Key 输入框
│   │   └── PreferencePickerView.swift # 偏好选择器
│   │
│   └── Components/
│       ├── ToastView.swift            # Toast 提示
│       ├── EmptyStateView.swift       # 通用空态
│       ├── ErrorView.swift            # 通用错误态
│       ├── ConfirmDialog.swift        # 确认弹窗
│       ├── TypeChip.swift             # 文章类型 Chip
│       └── GradientButton.swift       # 渐变按钮
│
├── Resources/
│   ├── Assets.xcassets/               # 图片、颜色、App Icon
│   ├── Colors/                        # 颜色定义
│   ├── Fonts/                         # （使用系统字体，不需要额外文件）
│   └── Sounds/                        # 可选音效文件
│
└── Preview Content/                   # SwiftUI Preview 数据
    └── Preview Assets.xcassets/
```

---

## 3. 核心架构设计

### 3.1 MVVM 数据流

```
┌──────────┐       ┌──────────────┐       ┌──────────┐
│   View   │ ←───→ │  ViewModel   │ ←───→ │  Service │
│ (SwiftUI)│ @State │ (Observable) │ calls │ (Actor)  │
└──────────┘       └──────────────┘       └──────────┘
                            │
                            ↓
                    ┌──────────────┐
                    │    Model     │
                    │ (@Model)     │
                    └──────────────┘
```

- **View**：纯 UI，不包含业务逻辑，通过 `@StateObject` / `@ObservedObject` 持有 ViewModel
- **ViewModel**：`@Observable` 类（iOS 17+ 宏），处理业务逻辑、状态管理、调用 Service
- **Service**：`actor` 或 `class`，处理数据持久化、网络请求、系统 API
- **Model**：`@Model` 宏（SwiftData），数据结构定义

### 3.2 依赖注入

使用 SwiftUI `Environment` + 手动注入：

```swift
// App Entry
@main
struct AidearApp: App {
    @State private var speechService = SpeechService()
    @State private var articleStore = ArticleStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(speechService)
                .environment(articleStore)
                .modelContainer(for: [Article.self, ChatMessage.self])
        }
    }
}
```

### 3.3 数据模型

```swift
@Model
final class Article {
    var id: UUID
    var title: String
    var subtitle: String          // 引语
    var content: String            // Markdown 正文
    var rawInput: String           // 原始输入
    var alternativeTitles: [String] // 备用标题（存储为 JSON string）
    var articleType: ArticleType
    var tone: Tone
    var targetLength: TargetLength
    var wordCount: Int
    var createdAt: Date
    var updatedAt: Date
    var chatMessages: [ChatMessage]? // 关联的对话历史
    
    init(/* ... */) { /* ... */ }
}

enum ArticleType: String, Codable {
    case opinion    // 观点文
    case knowledge  // 干货文
    case story      // 故事文
    case news       // 资讯文
    case freeform   // 自由风格
}

enum Tone: String, Codable {
    case formal     // 正式专业
    case casual     // 轻松亲切
    case sharp      // 犀利有料
    case warm       // 温暖治愈
}

enum TargetLength: String, Codable {
    case short      // ~800字
    case medium     // ~1500字
    case long       // ~2500字
}

@Model
final class ChatMessage {
    var id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date
    var article: Article?
}

enum MessageRole: String, Codable {
    case user
    case assistant
}
```

### 3.4 AI 服务抽象

```swift
protocol AIServiceProtocol {
    func generateArticle(
        input: String,
        config: GenerationConfig,
        streamCallback: ((String) -> Void)?
    ) async throws -> ArticleGenerationResult
    
    func adjustArticle(
        article: Article,
        instruction: String,
        chatHistory: [ChatMessage],
        streamCallback: ((String) -> Void)?
    ) async throws -> String
    
    func generateAlternativeTitles(
        article: Article,
        count: Int
    ) async throws -> [String]
    
    func validateAPIKey() async throws -> Bool
}

struct ArticleGenerationResult {
    let title: String
    let alternativeTitles: [String]
    let subtitle: String
    let content: String    // Markdown
    let wordCount: Int
}
```

### 3.5 语音服务

```swift
@Observable
final class SpeechService {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private let audioEngine = AVAudioEngine()
    
    var isRecording = false
    var transcribedText = ""
    var isRecognitionAvailable = false
    
    func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus
    func startRecording() throws
    func stopRecording() -> String
    func cancelRecording()
}
```

使用设备端识别优先（`requiresOnDeviceRecognition = true`），保护隐私。

---

## 4. 网络层

### 4.1 API 调用模式

```
View → ViewModel → AIServiceProtocol (actor) → URLSession (async/await)
                                                      │
                                                      ↓
                                               OpenAI / Anthropic API
                                               (streaming via AsyncThrowingStream)
```

### 4.2 流式响应处理

```swift
func generateArticle(
    input: String,
    config: GenerationConfig,
    streamCallback: ((String) -> Void)?
) async throws -> ArticleGenerationResult {
    let request = buildRequest(input: input, config: config)
    let (stream, _) = try await URLSession.shared.bytes(for: request)
    
    var fullResponse = ""
    for try await line in stream.lines {
        if line.hasPrefix("data: ") {
            let chunk = parseSSEChunk(line)
            fullResponse += chunk
            streamCallback?(chunk)
        }
        if line == "data: [DONE]" { break }
    }
    
    return parseArticle(from: fullResponse)
}
```

### 4.3 重试与容错

- 网络失败自动重试 2 次（间隔 1s、3s）
- 请求超时：15s
- 流式中断：保留已生成内容，提示用户可继续

---

## 5. 数据持久化

### 5.1 SwiftData 配置

```swift
@Model
final class Article { /* ... */ }

// ModelContainer 配置
let schema = Schema([Article.self, ChatMessage.self])
let modelConfiguration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    cloudKitDatabase: .automatic // 可选 iCloud 同步
)
let modelContainer = try ModelContainer(
    for: schema,
    configurations: [modelConfiguration]
)
```

### 5.2 用户偏好（轻量）

```swift
// 使用 @AppStorage
@AppStorage("defaultArticleType") var defaultArticleType: ArticleType = .freeform
@AppStorage("defaultTone") var defaultTone: Tone = .casual
@AppStorage("defaultLength") var defaultLength: TargetLength = .medium
@AppStorage("colorScheme") var colorScheme: String = "system"
@AppStorage("hapticEnabled") var hapticEnabled: Bool = true
```

### 5.3 Keychain 存储

```swift
// API Key 安全存储
enum KeychainManager {
    static func save(key: String, value: String) throws
    static func read(key: String) throws -> String?
    static func delete(key: String) throws
}
```

---

## 6. 安全设计

| 安全点 | 实现 |
|--------|------|
| API Key 存储 | Keychain（加密存储，不落盘明文） |
| 网络传输 | HTTPS only（强制） |
| 用户数据 | 仅本地存储 + 可选 iCloud（用户自己的账号） |
| 第三方服务 | 仅向用户配置的 AI 服务商发送数据 |
| 崩溃日志 | 不收集个人内容 |
| App Transport Security | 默认安全配置，不允许降级 |

---

## 7. 性能优化

| 优化点 | 方案 |
|--------|------|
| 列表性能 | SwiftUI `List` + `LazyVStack`，文章列表 Diffable |
| 大文本渲染 | 分段渲染，避免单次 AttributedString 过长 |
| 图片导出 | 后台线程渲染（`Task.detached`） |
| 语音识别 | 使用设备端模型（低延迟、离线可用） |
| AI 请求 | 流式响应，边收边展示，降低感知等待 |

---

## 8. 测试策略

| 层级 | 覆盖范围 | 工具 |
|------|----------|------|
| 单元测试 | Service 层、ViewModel 逻辑 | XCTest / Swift Testing |
| 集成测试 | AI Service + 真实 API（沙盒 Key） | XCTest |
| UI 测试 | 核心用户流程 | XCUITest |
| 快照测试 | 关键 UI 状态对比 | 可选第三方库 |

**最低测试覆盖率目标**：核心 Service 层 ≥ 80%

---

## 9. CI / CD（后续搭建）

- **CI**：GitHub Actions / Xcode Cloud
- **构建**：自动运行测试 + 构建验证
- **分发**：TestFlight（Beta）/ App Store Connect（Release）

---

*文档版本：v1.0 | 最后更新：2026-05-12*
