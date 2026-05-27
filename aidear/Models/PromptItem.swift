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
