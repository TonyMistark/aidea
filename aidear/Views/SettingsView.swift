import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String
    @State private var apiBaseURL: String
    @State private var modelName: String
    @State private var promptText: String
    @State private var showPromptResetAlert = false

    init() {
        let defaults = UserDefaults.standard
        _apiKey = State(initialValue: defaults.string(forKey: "api_key") ?? "")
        _apiBaseURL = State(initialValue: defaults.string(forKey: "api_base_url") ?? "https://api.openai.com/v1")
        _modelName = State(initialValue: defaults.string(forKey: "model_name") ?? "gpt-4o")
        let savedPrompt = defaults.string(forKey: "custom_prompt") ?? AppSettings.defaultPrompt
        _promptText = State(initialValue: savedPrompt)
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
                        settings.customPrompt = promptText
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                } footer: {
                    Text("未配置 API Key 时将使用模拟生成，供你体验 App 流程。")
                }

                // MARK: - AI Prompt 编辑

                Section {
                    TextEditor(text: $promptText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 300)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 0.5)
                        )

                    HStack {
                        Text("\(promptText.count) 字")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("恢复默认", role: .destructive) {
                            showPromptResetAlert = true
                        }
                        .font(.caption)
                    }
                } header: {
                    Text("AI Prompt")
                } footer: {
                    Text("修改后将用于所有新生成的文章。点击「保存」后生效。")
                }
                .alert("恢复默认 Prompt", isPresented: $showPromptResetAlert) {
                    Button("取消", role: .cancel) {}
                    Button("恢复", role: .destructive) {
                        promptText = AppSettings.defaultPrompt
                    }
                } message: {
                    Text("这将覆盖你当前的自定义 Prompt，确定恢复？")
                }
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
}
