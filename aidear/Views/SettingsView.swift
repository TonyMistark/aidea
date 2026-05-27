import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String
    @State private var apiBaseURL: String
    @State private var modelName: String

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
            .navigationDestination(for: PromptEditorState.self) { state in
                promptEditor(state: state)
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
                    // Tap circle to set active
                    Button {
                        settings.activePromptID = prompt.id
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: prompt.id == settings.activePromptID
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(prompt.id == settings.activePromptID
                                             ? .blue : .secondary)
                            .font(.body)
                    }
                    .buttonStyle(.plain)

                    NavigationLink(
                        value: PromptEditorState(id: prompt.id, name: prompt.name, content: prompt.content)
                    ) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prompt.name)
                                .font(.body)
                            Text(String(prompt.content.prefix(50))
                                 + (prompt.content.count > 50 ? "…" : ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }
            .onDelete(perform: deletePrompts)

            NavigationLink(
                value: PromptEditorState(id: nil, name: "", content: "")
            ) {
                Label("添加 Prompt", systemImage: "plus.circle")
            }
        } header: {
            Text("AI Prompt")
        } footer: {
            Text("点击设为当前生效的 Prompt。点击  ✏️  编辑。左滑删除。")
        }
    }

    // MARK: - Prompt Editor (pushed via NavigationLink)

    private func promptEditor(state: PromptEditorState) -> some View {
        PromptEditView(
            editingID: state.id,
            initialName: state.name,
            initialContent: state.content
        )
    }

    // MARK: - Delete

    private func deletePrompts(at offsets: IndexSet) {
        guard settings.prompts.count > 1 else { return }
        for index in offsets {
            settings.deletePrompt(id: settings.prompts[index].id)
        }
    }
}

// MARK: - Prompt Editor State (for NavigationLink value)

struct PromptEditorState: Hashable, Identifiable {
    let id: UUID?  // nil = new prompt
    let name: String
    let content: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
    }

    static func == (lhs: PromptEditorState, rhs: PromptEditorState) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}

// MARK: - Prompt Edit View (pushed, not sheet)

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
