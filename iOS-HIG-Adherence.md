# Aidear iOS 人机界面指南合规文档

---

## 1. 合规总览

本文档确保 Aidear 严格遵循 Apple 的 [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines)（HIG），在 App Store 审核和用户体验两方面都达到 Apple 标准。

---

## 2. 核心设计原则对齐

### 2.1 Apple 六大设计原则

| Apple 原则 | Aidear 实现 |
|------------|------------|
| **清晰（Clarity）** | 整个 App 功能聚焦，首页只做一件事：录入想法。文字醒目，图标精确，不堆砌功能。 |
| **顺从（Deference）** | UI 让位于内容。使用系统半透明材质（`.ultraThinMaterial`），让文章内容成为视觉焦点。 |
| **深度（Depth）** | 使用系统导航转场（push/pop）、sheet 弹出、全屏覆盖，建立清晰的层级感。录音按钮的外圈涟漪动画暗示空间深度。 |
| **一致性（Consistency）** | 全部使用 SF Symbols 5、系统字体、系统颜色、标准导航栏、Tab Bar。用户 0 学习成本。 |
| **直接操作（Direct Manipulation）** | 按住录音、左滑删除、长按多选、滑动切换标题、下拉返回。所有操作都有即时反馈。 |
| **反馈（Feedback）** | 每个操作都有触觉反馈、动画反馈或文字提示。录音有声波、按钮有缩放、生成有进度、复制有 Toast。 |

---

## 3. 导航合规

### 3.1 Tab Bar

```
✅ 使用系统 UITabBarController（SwiftUI TabView）
✅ 3 个 Tab（Apple 建议 2-5 个）
✅ 每个 Tab 有 SF Symbol 图标 + 简短标题
✅ 图标使用 fill 变体（Apple 推荐）
✅ 选中态使用主色（非自定义图片）
```

### 3.2 导航栈

```
✅ 使用 NavigationStack（iOS 16+ 标准）
✅ 标准返回按钮（只显示图标 <）
✅ 页面标题使用 .navigationTitle
✅ 大标题用于顶级页面（首页/历史）
✅ 内联标题用于子页面
✅ 右滑返回手势保留（不使用自定义手势覆盖）
```

### 3.3 模态与弹窗

```
✅ Sheet 使用标准 .sheet modifier
✅ 底部 Sheet 有 drag indicator
✅ 使用 .presentationDetents 控制 Sheet 高度（.medium, .large）
✅ 弹窗使用 .alert（系统 Alert）
✅ 不用自定义弹窗覆盖系统交互
✅ 确认危险操作使用 .confirmationDialog
```

---

## 4. 视觉设计合规

### 4.1 色彩

```
✅ 使用系统语义色（label, secondaryLabel, systemBackground 等）
   确保浅色/深色模式自动适配
✅ 品牌色使用自定义色值，但保证与系统背景有足够对比度
✅ 不依赖纯颜色传达信息（同时使用图标/文字）
✅ 深色模式下品牌色适当调整亮度（主色在深色背景上更亮）
```

**对比度检查清单**：

| 元素 | 要求 | 检查 |
|------|------|------|
| Body 文字 (#label on #systemBackground) | ≥ 4.5:1 | ✅ 系统保证 |
| 大标题 | ≥ 3:1 | ✅ 系统保证 |
| 主色按钮（白色图标 on #F59E0B） | ≥ 3:1 | ✅ 需验证 |
| 次要文字 (#secondaryLabel) | ≥ 3:1（17pt+） | ✅ 系统保证 |
| 错误文字 (#FF3B30) | ≥ 4.5:1 | ✅ 系统保证 |

### 4.2 字体

```
✅ 所有文字使用 SF Pro 系统字体
✅ 使用 Dynamic Type 语义字号（.title, .body, .headline 等）
✅ 不使用硬编码字号（使用 .font(.body) 而非 .font(.system(size: 17)))
✅ 正文行高 ≥ 1.5（文章内容使用 1.8）
✅ 段落宽度合理（不使用全屏宽度的大段文字）
✅ 字体缩放范围：xSmall 到 xxxLarge（Accessibility 大小在 5.3 节处理）
```

### 4.3 间距与布局

```
✅ 使用 SwiftUI 默认间距作为基准
✅ 自定义间距使用 8pt 网格
✅ 内容区域左右留白 ≥ 16pt
✅ 可点击区域最小 44×44pt（Apple HIG 要求）
✅ 安全区域完全遵守（safeAreaInsets）
✅ 列表使用 .insetGrouped 样式（设置页）
```

**44pt 最小触控区域检查**：

| 交互元素 | 尺寸 | 合规 |
|----------|------|------|
| 录音按钮 | 80×80pt | ✅ |
| 生成按钮 | 全宽 × 56pt | ✅ |
| 文章类型选择 Chip | 高度 40pt | ⚠️ 需确保宽度 ≥ 44pt |
| Tab Bar 项 | 系统默认 | ✅ |
| 导航栏按钮 | 系统默认 | ✅ |
| 搜索栏 | 系统默认 | ✅ |
| 快捷指令 Chip | 高度 36pt | ⚠️ 需确保宽度 ≥ 44pt |

### 4.4 图标

```
✅ 全部使用 SF Symbols 5
✅ 选择与语义一致的 symbol 名称
✅ 使用 .fill 变体用于选中/激活态
✅ 图标大小使用系统语义（.largeTitle, .title 等 Image.Scale）
✅ 不自定义绘制图标（除非品牌 Logo 需要）
✅ 不使用 emoji 替代 UI 图标
```

---

## 5. 无障碍合规

### 5.1 VoiceOver

```
✅ 所有交互元素有 .accessibilityLabel
✅ 装饰性元素使用 .accessibilityHidden(true)（如声波动画、粒子动画）
✅ 分组内容使用 .accessibilityElement(children: .combine)
✅ 动态内容更新时发送 .accessibilityAnnouncement
✅ 录音按钮 VoiceOver 操作：双击开始/停止录音
```

**关键元素 VoiceOver 标签**：

| 元素 | Label | Hint |
|------|-------|------|
| 录音按钮（空闲） | "开始录音" | "双击并按住开始录制想法" |
| 录音按钮（录音中） | "停止录音" | "双击停止录制" |
| 生成按钮 | "开始生成文章" | "使用当前设置生成文章" |
| 生成中 | "正在生成文章，已完成 60%" | — |
| 文章卡片 | "{标题}，{时间}，{字数}" | "双击查看文章" |
| 删除操作 | "删除{标题}" | "此操作不可撤销" |

### 5.2 Dynamic Type

```
✅ 所有文字使用 .font(.system(.body)) 等语义字体
✅ 关键按钮文字支持辅助功能大字体
✅ 文章正文字体上限放大到 1.5 倍（保留可读性）
✅ 在 Xcode Accessibility Inspector 中验证所有字号
```

**Dynamic Type 行为表**：

| 字号档位 | Body 实际大小 | 应对策略 |
|----------|--------------|----------|
| xSmall - Large | 14pt - 17pt | 正常展示 |
| Extra Large | 18pt - 21pt | 正常缩放，列表行高自适应 |
| AX1 - AX3 | 22pt - 28pt | 部分 Chip 可能折行，可接受 |
| AX4 - AX5 | 30pt+ | 减少单页信息密度，关键按钮保持可见 |

### 5.3 动态字体下的布局适配

```
✅ 使用 ScrollView 包裹内容，字体放大后可滚动
✅ 录音按钮等关键元素使用固定尺寸（不随字体缩放）
✅ 文字标签使用 .lineLimit 确保不溢出
✅ Tab Bar 标签在 AX 字体下可能隐藏，依赖图标
```

### 5.4 辅助功能

```
✅ 支持"降低透明度"设置（不使用透明效果传达关键信息）
✅ 支持"增强对比度"（关键分割线/边框在增强对比度下更明显）
✅ 支持"减弱动态效果"（关闭生成粒子动画、减少录音涟漪层数）
✅ 触觉反馈可通过"系统振动"关闭（使用 .sensoryFeedback 自动跟随系统）
```

---

## 6. 交互合规

### 6.1 手势

```
✅ 标准左滑返回（NavigationStack 内置）
✅ 长按用于次要操作（历史多选），不用于核心操作
✅ 下滑用于关闭 Sheet / 收起键盘
✅ 不使用自定义手势覆盖系统手势
✅ 所有手势操作有撤销/取消方式
```

### 6.2 触觉反馈

```
✅ 使用 .sensoryFeedback modifier（iOS 17+）
✅ 跟随系统"振动"设置（用户关闭则静默）
✅ 触觉反馈与动画同步
✅ 不在后台持续使用触觉引擎
```

### 6.3 加载状态

```
✅ 网络请求有加载指示器（非模态，不阻塞 UI）
✅ AI 生成使用全屏但可后台（尊重用户耐心）
✅ 使用 .interactiveDismissDisabled 仅在必要时（生成中 3 秒内不可取消）
✅ 后台任务有进度指示
```

### 6.4 错误处理

```
✅ 使用系统 Alert 展示关键错误（非自定义弹窗）
✅ 轻量错误使用内联提示/Toast
✅ 每个错误提供明确的恢复操作
✅ 不使用技术术语描述错误（面向普通用户）
```

---

## 7. 平台适配

### 7.1 iPhone

```
✅ 竖屏为主方向（所有页面优化竖屏）
✅ 横屏支持（文章预览页和文字输入页支持横屏）
✅ 适配所有 iPhone 屏幕尺寸（从 iPhone SE 到 Pro Max）
✅ 使用 GeometryReader 仅在必要时
✅ Safe Area 尊重（刘海屏/灵动岛）
```

### 7.2 灵动岛（Dynamic Island）

```
暂不使用灵动岛展示信息（V1.0）。
P2 可考虑：录音时在灵动岛显示波形/时长。
```

### 7.3 iPad（P2）

```
P2 计划：
✅ 使用 NavigationSplitView 适配大屏
✅ 支持 Slide Over / Split View
✅ 支持 Apple Pencil 手写输入（Scribble）
✅ 键盘快捷键（iPad 外接键盘）
```

---

## 8. 隐私合规

### 8.1 权限请求

```
✅ 麦克风：Info.plist 添加 NSMicrophoneUsageDescription
   文案："Aidear 需要麦克风权限来将你的语音想法转为文字"
✅ 语音识别：Info.plist 添加 NSSpeechRecognitionUsageDescription
   文案："Aidear 使用语音识别将你的录音转为文字内容"
✅ 预引导：系统弹窗前先展示 App 内说明（为什么需要此权限）
```

### 8.2 数据隐私

```
✅ 用户文章只存储在本地设备和用户自己的 iCloud 账号
✅ API Key 存储在 Keychain
✅ 不收集使用数据（除非用户主动反馈）
✅ PrivacyInfo.xcprivacy 文件完整填写（App Store 必需）
✅ 不包含任何第三方分析/广告 SDK
```

### 8.3 网络隐私

```
✅ 仅向用户配置的 AI 服务商发送数据
✅ 使用 HTTPS 加密传输
✅ App Transport Security 使用默认配置
✅ 隐私政策清晰说明数据传输范围
```

---

## 9. App Store 审核清单

### 9.1 必检项目

| 检查项 | 状态 | 备注 |
|--------|------|------|
| 无崩溃 | ⬜ 提交前验证 | TestFlight 充分测试 |
| 无占位符内容 | ⬜ 提交前验证 | 所有 UI 文案为最终版本 |
| 无私有 API 调用 | ✅ | 全部使用公开 API |
| 无隐藏功能 | ✅ | 所有功能可见可用 |
| 权限说明完整 | ⬜ 提交前添加 | Info.plist 权限描述 |
| PrivacyInfo.xcprivacy | ⬜ 提交前创建 | 必需的隐私清单 |
| 最低 OS 版本合理 | ✅ | iOS 17.0 |
| 无订阅欺诈 | ✅ | 无订阅，用户自带 API Key |
| App Icon 合规 | ⬜ 提交前设计 | 不使用 Apple 产品图像 |
| 截图真实 | ⬜ 提交前截取 | 不做虚假宣传 |

### 9.2 常见拒审原因预防

| 拒审原因 | 预防措施 |
|----------|----------|
| 功能不完整 | 确保 V1.0 核心流程完整可闭环 |
| 权限过度 | 只请求麦克风和语音识别（最少的必要权限） |
| 界面粗糙 | 严格遵循本文档的 UI 设计规范 |
| 崩溃/Bug | 充分测试，使用 TestFlight 收集反馈 |
| 隐私缺失 | 完善隐私政策和隐私清单 |
| 误导用户 | 明确说明需要用户自行提供 API Key |

---

## 10. SwiftUI 最佳实践（iOS 17+）

### 10.1 推荐使用的 Modifier

```swift
// 触觉反馈
.sensoryFeedback(.impact(weight: .light), trigger: someAction)

// 内容过渡
.contentTransition(.numericText())

// 滚动相关
.scrollDismissesKeyboard(.interactively)
.scrollIndicators(.hidden)

// SF Symbols 动画
.symbolEffect(.bounce, options: .repeating, value: isRecording)

// Sheet 控制
.presentationDetents([.medium, .large])
.presentationDragIndicator(.visible)
.presentationBackground(.regularMaterial)

// 无障碍
.accessibilityLabel("开始录音")
.accessibilityHint("双击并按住开始录制您的想法")
.accessibilityHidden(true) // 装饰元素
```

### 10.2 避免的模式

```
❌ 避免 @ObservedObject（使用 iOS 17+ 的 @Observable 宏）
❌ 避免自定义 Navigation（使用 NavigationStack）
❌ 避免 UIViewControllerRepresentable 除非必要
❌ 避免手动布局计算（使用 SwiftUI 布局系统）
❌ 避免过度使用 .frame(width:height:) 硬编码尺寸
❌ 避免在 View 初始化中执行副作用
❌ 避免在 body 中进行复杂计算（使用 ViewModel）
```

---

*文档版本：v1.0 | 最后更新：2026-05-12*
