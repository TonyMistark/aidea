# 多 Prompt 管理 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single custom prompt with multi-prompt management: create multiple named prompts, select one as active, switch/edit/add/delete freely.

**Design principles (from product docs):**
- 简洁 — no extra View files, everything in existing files
- iOS 原生 — Form Section with standard rows, sheet for editing, swipe-to-delete
- SF Symbols only, system semantic colors, 44pt touch targets
- HIG compliant: `.fill` for selected state, haptic on selection

**Architecture:** `PromptItem` model + `prompts` array in `AppSettings`. Inline prompt list section in `SettingsView` (Form rows + sheet editor). `GenerationService` reads active prompt content. No new files beyond the model.

**Tech Stack:** Swift, SwiftUI, Codable, UserDefaults

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `aidear/Models/PromptItem.swift` | **Create** | `PromptItem` struct (id, name, content) |
| `aidear/Models/AppSettings.swift` | **Modify** | `customPrompt: String` → `prompts: [PromptItem]` + `activePromptID: UUID` |
| `aidear/Views/SettingsView.swift` | **Modify** | Replace TextEditor section with prompt list + inline sheet editor |
| `aidear/Services/GenerationService.swift` | **Modify** | `settings.customPrompt` → `settings.activePromptContent` |

---

### Task 1: Create `PromptItem` model

**Files:**
- Create: `aidear/Models/PromptItem.swift`

- [ ] **Step 1: Create the PromptItem struct**

```swift
import Foundation

struct PromptItem: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var content: String

    init(id: UUID = UUID(), name: String, content: String) {
        self.id = id
        self.name = name
        self.content = content
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add aidear/Models/PromptItem.swift
git commit -m "feat: add PromptItem model for multi-prompt support"
```

---

### Task 2: Refactor `AppSettings` to support multiple prompts

**Files:**
- Modify: `aidear/Models/AppSettings.swift`

- [ ] **Step 1: Replace single-prompt with multi-prompt storage**

Replace the entire file:

```swift
import Foundation

final class AppSettings: ObservableObject {
    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: "api_key") }
    }
    @Published var apiBaseURL: String {
        didSet { UserDefaults.standard.set(apiBaseURL, forKey: "api_base_url") }
    }
    @Published var modelName: String {
        didSet { UserDefaults.standard.set(modelName, forKey: "model_name") }
    }

    // MARK: - Multi-prompt

    @Published var prompts: [PromptItem] {
        didSet { savePrompts() }
    }
    @Published var activePromptID: UUID {
        didSet { UserDefaults.standard.set(activePromptID.uuidString, forKey: "active_prompt_id") }
    }

    var activePromptContent: String {
        prompts.first(where: { $0.id == activePromptID })?.content ?? Self.defaultPrompt
    }

    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "api_key") ?? ""
        self.apiBaseURL = UserDefaults.standard.string(forKey: "api_base_url") ?? "https://api.openai.com/v1"
        self.modelName = UserDefaults.standard.string(forKey: "model_name") ?? "gpt-4o"

        // Load prompts — migrate from old single-prompt format
        if let data = UserDefaults.standard.data(forKey: "prompts"),
           let decoded = try? JSONDecoder().decode([PromptItem].self, from: data),
           !decoded.isEmpty {
            self.prompts = decoded
        } else if let oldPrompt = UserDefaults.standard.string(forKey: "custom_prompt") {
            self.prompts = [PromptItem(name: "默认", content: oldPrompt)]
        } else {
            self.prompts = [PromptItem(name: "默认", content: Self.defaultPrompt)]
        }

        if let idString = UserDefaults.standard.string(forKey: "active_prompt_id"),
           let id = UUID(uuidString: idString),
           self.prompts.contains(where: { $0.id == id }) {
            self.activePromptID = id
        } else {
            self.activePromptID = self.prompts[0].id
        }
    }

    var isConfigured: Bool { !apiKey.isEmpty }

    @discardableResult
    func addPrompt(name: String, content: String) -> UUID {
        let item = PromptItem(name: name, content: content)
        prompts.append(item)
        return item.id
    }

    func deletePrompt(id: UUID) {
        prompts.removeAll { $0.id == id }
        if !prompts.contains(where: { $0.id == activePromptID }), let first = prompts.first {
            activePromptID = first.id
        }
    }

    private func savePrompts() {
        if let data = try? JSONEncoder().encode(prompts) {
            UserDefaults.standard.set(data, forKey: "prompts")
        }
    }

    static let defaultPrompt = """
    你是一个专业的微信公众号文章写手。你的任务是将用户提供的零散想法、关键词或短句，扩展成一篇结构完整、可读性强、适合手机阅读的公众号文章。

    ## 写作要求

    ### 标题
    - 10-25 字，生动具体，让读者有点击欲望
    - 不要说"关于XX的思考"，要说"XX 教会我的 3 件事"
    - 数字、对比、悬念都是好技巧

    ### 正文结构
    - 正文从 ## 二级标题开始，不要重复使用文章标题作为 H1
    - 用 ## 和 ### 在自然的话题边界处建立层级，帮读者快速扫读
    - 每个段落控制在 3-5 行（手机屏幕约 150 字），段落之间留空行
    - 开门见山：第一段就点出文章要讲什么

    ### 排版规则
    - 核心观点、关键结论用 **粗体** 标出，但一篇文章中粗体不要超过 8 处
    - 并列的观点、步骤、清单用有序或无序列表
    - 对比信息、选项矩阵用表格
    - 金句、值得被读者划线的句子用 > 引用块
    - 中文与英文、数字之间自动加空格（如 "iPhone 15"、"2024 年"）

    ### 风格
    - 像给朋友分享观点一样自然，不要说教，不要喊口号
    - 用具体的例子和细节支撑观点，不要只堆结论
    - 结尾要有行动指引或思考延伸，让读者感到"有收获"
    - 全文 500-1000 字

    ### 摘要
    - 提供一句 punchy 的摘要（50-80 字），适合转发分享时展示
    - 摘要要自包含，包含具体的信息量（数字、方法、结论）

    ### 封面图提示词
    - 为这篇文章生成一个封面图描述，用于 AI 图片生成工具
    - 中文描述，50-100 字
    - 从以下维度描述你想要的画面：
              类型（概念插画/场景/极简/文字主导）
              色调（暖色/高级灰/冷色/暗色/大地色/鲜艳/粉彩/复古/双色调）
              风格（扁平矢量/手绘/数字绘画/像素风/版画风）
              画面要留 40-60% 的留白空间，主体居中或偏左
    - 封面图不要出现真实人物面部，用简化的轮廓替代

    输出 JSON 格式：
    {
      "title": "文章标题",
      "summary": "一句话摘要，50-80字",
      "content": "Markdown 正文",
      "cover_image_prompt": "封面图生成提示词，中文，50-100字"
    }
    """
}
```

- [ ] **Step 2: Build check**

Run: `cd /Users/ice/projects/aidear && xcodebuild -project aidear.xcodeproj -scheme aidear -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20`
Expected: errors on `settings.customPrompt` in other files (expected, fixed in later tasks)

- [ ] **Step 3: Commit**

```bash
git add aidear/Models/AppSettings.swift
git commit -m "feat: AppSettings supports multiple prompts with active selection"
```

---

### Task 3: Update `GenerationService`

**Files:**
- Modify: `aidear/Services/GenerationService.swift:70-72`

- [ ] **Step 1: Change systemPrompt to read activePromptContent**

```swift
private var systemPrompt: String {
    settings.activePromptContent
}
```

- [ ] **Step 2: Commit**

```bash
git add aidear/Services/GenerationService.swift
git commit -m "fix: GenerationService reads activePromptContent"
```

---

### Task 4: Refactor `SettingsView` — prompt list + sheet editor

**Files:**
- Modify: `aidear/Views/SettingsView.swift`

- [ ] **Step 1: Replace entire SettingsView**

The key design decisions:
- Prompt list is a Section in the existing Form (no new files)
- Each row: name + content preview, checkmark if active, tap to select
- Pencil button on each row opens sheet editor (inline `PromptEditorView`)
- "+" button in section header to add new prompts
- Swipe-to-delete with last-prompt guard
- Editor: name TextField + content TextEditor, cancel/save in toolbar, 恢复默认 button
- Save button no longer touches prompt (prompts save on edit via `didSet`)

```swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String
    @State private var apiBaseURL: String
    @State private var modelName: String

    // Prompt editing state
    @State private var editingPromptID: UUID?
    @State private var editName = ""
    @State private var editContent = ""
    @State private var showResetAlert = false

    init() {
        let defaults = UserDefaults.standard
        _apiKey = State(initialValue: defaults.string(forKey: "api_key") ?? "")
        _apiBaseURL = State(initialValue: defaults.string(forKey: "api_base_url") ?? "https://api.openai.com/v1")
        _modelName = State(initialValue: defaults.string(forKey: "model_name") ?? "gpt-4o")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("sk-...", text: $apiKey)
                        .font(.system(.body, design: .monospaced))
                } header: {
                    Text("API Key")
                } footer: {
                    Text("支持 OpenAI 或兼容接口")
                }

                Section {
                    TextField("https://api.openai.com/v1", text: $apiBaseURL)
                        .font(.system(.body, design: .monospaced))
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                } header: {
                    Text("API 地址")
                } footer: {
                    Text("留空使用默认 OpenAI 地址")
                }

                Section {
                    TextField("gpt-4o", text: $modelName)
                } header: {
                    Text("模型名称")
                }

                Section {
                    Button("保存") {
                        settings.apiKey = apiKey
                        settings.apiBaseURL = apiBaseURL
                        settings.modelName = modelName
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                } footer: {
                    Text("未配置 API Key 时将使用模拟生成，供你体验 App 流程。")
                }

                // MARK: - Prompt 管理
                promptSection
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    // MARK: - Prompt List Section

    private var promptSection: some View {
        Section {
            ForEach(settings.prompts) { prompt in
                HStack(spacing: 12) {
                    Image(systemName: prompt.id == settings.activePromptID
                          ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(prompt.id == settings.activePromptID
                                         ? .blue : .secondary)
                        .font(.body)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(prompt.name)
                            .font(.body)
                        Text(String(prompt.content.prefix(50))
                             + (prompt.content.count > 50 ? "…" : ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        startEditing(prompt: prompt)
                    } label: {
                        Image(systemName: "pencil")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.borderless)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    settings.activePromptID = prompt.id
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
            .onDelete(perform: deletePrompts)

            Button {
                startNewPrompt()
            } label: {
                Label("添加 Prompt", systemImage: "plus.circle")
            }
        } header: {
            Text("AI Prompt")
        } footer: {
            Text("点击设为当前生效的 Prompt。点击   编辑。左滑删除。")
        }
        .sheet(isPresented: Binding(
            get: { editingPromptID != nil },
            set: { if !$0 { editingPromptID = nil } }
        )) {
            promptEditorSheet
        }
    }

    // MARK: - Prompt Editor (inline sheet)

    private var promptEditorSheet: some View {
        NavigationStack {
            Form {
                Section("名称") {
                    TextField("Prompt 名称", text: $editName)
                }

                Section {
                    TextEditor(text: $editContent)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 300)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 0.5)
                        )

                    HStack {
                        Text("\(editContent.count) 字")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        if let id = editingPromptID,
                           let prompt = settings.prompts.first(where: { $0.id == id }),
                           prompt.content == AppSettings.defaultPrompt || true {
                            Button("恢复默认", role: .destructive) {
                                showResetAlert = true
                            }
                            .font(.caption)
                        }
                    }
                } header: {
                    Text("Prompt 内容")
                }
            }
            .navigationTitle("编辑 Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { editingPromptID = nil }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveEditingPrompt()
                        editingPromptID = nil
                    }
                    .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("恢复默认 Prompt", isPresented: $showResetAlert) {
                Button("取消", role: .cancel) {}
                Button("恢复", role: .destructive) {
                    editContent = AppSettings.defaultPrompt
                }
            } message: {
                Text("这将覆盖当前 Prompt 内容，确定恢复？")
            }
        }
    }

    // MARK: - Prompt Actions

    private func startEditing(prompt: PromptItem) {
        editingPromptID = prompt.id
        editName = prompt.name
        editContent = prompt.content
    }

    private func startNewPrompt() {
        editingPromptID = UUID()  // temp ID to open sheet
        editName = ""
        editContent = ""
    }

    private func saveEditingPrompt() {
        guard let id = editingPromptID else { return }
        if let index = settings.prompts.firstIndex(where: { $0.id == id }) {
            settings.prompts[index].name = editName
            settings.prompts[index].content = editContent
        } else {
            // New prompt (ID was temp)
            let newItem = PromptItem(id: id, name: editName, content: editContent)
            settings.prompts.append(newItem)
            settings.activePromptID = id
        }
    }

    private func deletePrompts(at offsets: IndexSet) {
        guard settings.prompts.count > 1 else { return }
        for index in offsets {
            settings.deletePrompt(id: settings.prompts[index].id)
        }
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `cd /Users/ice/projects/aidear && xcodebuild -project aidear.xcodeproj -scheme aidear -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add aidear/Views/SettingsView.swift
git commit -m "feat: prompt list with active selection, sheet editor, add/delete"
```

---

### Task 5: Build verification + manual test

- [ ] **Step 1: Clean build**

Run: `cd /Users/ice/projects/aidear && xcodebuild -project aidear.xcodeproj -scheme aidear -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 2: Manual test checklist**

1. Fresh launch → Settings shows one "默认" prompt with blue checkmark
2. Tap pencil on "默认" → sheet opens with name and full prompt content
3. Cancel → nothing changed
4. Tap pencil again → edit name to "我的风格", edit content, save → list updates
5. Tap "添加 Prompt" → sheet opens with empty fields
6. Name "短文版", custom content, save → new row appears with checkmark
7. Tap old "我的风格" row → checkmark moves to it, light haptic
8. Generate article → uses "我的风格" prompt content
9. Swipe to delete a prompt → removed, if active was deleted → checkmark moves to first
10. Only one prompt left → swipe delete is blocked
11. Light/dark mode → all colors adapt via system semantic colors

- [ ] **Step 3: Final commit if fixes needed**

```bash
git add -A && git commit -m "fix: multi-prompt edge cases after testing"
```
