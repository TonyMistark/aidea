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
