import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String
    @State private var apiBaseURL: String
    @State private var modelName: String

    // Delete confirmation
    @State private var promptToDelete: UUID?

    // Edit sheet
    @State private var editPromptID: UUID?
    @State private var editPromptName = ""
    @State private var editPromptContent = ""
    @State private var showingEditor = false

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
            .alert("删除 Prompt", isPresented: Binding(
                get: { promptToDelete != nil },
                set: { if !$0 { promptToDelete = nil } }
            )) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    if let id = promptToDelete {
                        settings.deletePrompt(id: id)
                        promptToDelete = nil
                    }
                }
            } message: {
                Text("确定要删除这个 Prompt 吗？此操作不可撤销。")
            }
            .sheet(isPresented: $showingEditor) {
                NavigationStack {
                    PromptEditView(
                        editingID: editPromptID,
                        initialName: editPromptName,
                        initialContent: editPromptContent
                    )
                }
                .presentationDetents([.large])
            }
        }
    }

    // MARK: - Prompt List Section

    private var promptSection: some View {
        Section {
            ForEach(settings.prompts) { prompt in
                promptRow(prompt: prompt)
            }

            Button {
                editPromptID = nil
                editPromptName = ""
                editPromptContent = ""
                showingEditor = true
            } label: {
                Label("添加 Prompt", systemImage: "plus.circle")
            }
        } header: {
            Text("AI Prompt")
        } footer: {
            Text("点击设为当前生效的 Prompt。左滑可复制、编辑、删除。")
        }
    }

    private func promptRow(prompt: PromptItem) -> some View {
        HStack(spacing: 10) {
            // Active indicator
            Image(systemName: prompt.id == settings.activePromptID
                  ? "checkmark.circle.fill" : "circle")
                .foregroundColor(prompt.id == settings.activePromptID
                                 ? .blue : .secondary)
                .font(.body)
                .animation(.spring(response: 0.3, blendDuration: 0.2), value: settings.activePromptID)

            // Tap area for selection
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(prompt.name)
                        .font(.body)

                    if let source = promptSource(from: prompt.name) {
                        Text("（\(source)）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text(String(prompt.content.prefix(50))
                     + (prompt.content.count > 50 ? "…" : ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            settings.activePromptID = prompt.id
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Copy
            Button {
                copyPrompt(prompt: prompt)
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }
            .tint(.blue)

            // Edit
            Button {
                editPromptID = prompt.id
                editPromptName = prompt.name
                editPromptContent = prompt.content
                showingEditor = true
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            .tint(.orange)

            // Delete
            Button {
                promptToDelete = prompt.id
            } label: {
                Label("删除", systemImage: "trash")
            }
            .tint(.red)
        }
    }

    private func copyPrompt(prompt: PromptItem) {
        let copyCount = settings.prompts.filter { $0.name == prompt.name }.count
        let suffix = copyCount > 0 ? " 副本" : " 副本"
        let newName = prompt.name + suffix
        settings.addPrompt(name: newName, content: prompt.content)
    }

    private func promptSource(from name: String) -> String? {
        if name.hasSuffix(" 副本") { return "副本" }
        return nil
    }

    // MARK: - Delete (legacy, not used with swipe)

    private func deletePrompts(at offsets: IndexSet) {
        guard settings.prompts.count > 1 else { return }
        for index in offsets {
            settings.deletePrompt(id: settings.prompts[index].id)
        }
    }
}

// MARK: - Prompt Edit View (pushed via NavigationLink)

struct PromptEditView: View {
    let editingID: UUID?
    let initialName: String
    let initialContent: String

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var editName: String
    @State private var editContent: String
    @State private var showResetAlert = false

    init(editingID: UUID?, initialName: String, initialContent: String) {
        self.editingID = editingID
        self.initialName = initialName
        self.initialContent = initialContent
        _editName = State(initialValue: initialName)
        _editContent = State(initialValue: initialContent)
    }

    var body: some View {
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
                    Button("恢复默认", role: .destructive) {
                        showResetAlert = true
                    }
                    .font(.caption)
                }
            } header: {
                Text("Prompt 内容")
            }
        }
        .navigationTitle(editingID != nil ? "编辑 Prompt" : "添加 Prompt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    savePrompt()
                    dismiss()
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

    private func savePrompt() {
        if let id = editingID,
           let index = settings.prompts.firstIndex(where: { $0.id == id }) {
            settings.prompts[index].name = editName
            settings.prompts[index].content = editContent
        } else {
            let newID = settings.addPrompt(name: editName, content: editContent)
            settings.activePromptID = newID
        }
    }
}
