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

    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "api_key") ?? ""
        self.apiBaseURL = UserDefaults.standard.string(forKey: "api_base_url") ?? "https://api.openai.com/v1"
        self.modelName = UserDefaults.standard.string(forKey: "model_name") ?? "gpt-4o"
    }

    var isConfigured: Bool { !apiKey.isEmpty }
}
