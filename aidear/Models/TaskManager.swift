import Foundation

// MARK: - TaskStatus

enum TaskStatus: String, Codable, Sendable {
    case pending = "pending"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

// MARK: - GenerationTask

struct GenerationTask: Identifiable, Equatable {
    let id: UUID
    let inputText: String
    let inputMode: InputMode
    let promptID: UUID?
    let createdAt: Date
    
    var status: TaskStatus
    var result: GenerationResult?
    var errorMessage: String?
    var elapsedSeconds: Int
    var selectedThemeID: String
    
    static func == (lhs: GenerationTask, rhs: GenerationTask) -> Bool {
        lhs.id == rhs.id
    }
    
    var title: String {
        if ((result?.title.isEmpty) == nil) ?? false {
            return result!.title
        }
        let preview = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let truncated = preview.count > 30 ? String(preview.prefix(30)) + "…" : preview
        return truncated.isEmpty ? "\(inputMode.rawValue)" : truncated
    }
    
    var statusBadgeText: String {
        switch status {
        case .pending:   return "⏳ 等待中"
        case .running:   return "⚡ 生成中"
        case .completed: return "✅ 已完成"
        case .failed:    return "❌ 失败"
        case .cancelled: return "⛔ 已取消"
        }
    }
}

// MARK: - TaskManager

final class TaskManager: ObservableObject {
    static let shared = TaskManager()
    
    @Published private(set) var tasks: [GenerationTask] = [] {
        didSet { saveTasks() }
    }
    
    @Published var concurrentLimit: Int = 1
    
    /// Tasks that have been completed but not yet viewed by the user
    @Published var newlyCompletedIDs: Set<UUID> = []
    
    /// Currently running tasks count
    var runningCount: Int {
        tasks.filter { $0.status == .running }.count
    }
    
    /// Unread completed results count (newly completed, user hasn't viewed yet)
    var unreadCompletedCount: Int {
        newlyCompletedIDs.count
    }
    
    // MARK: - Private
    
    private var savedTasksData: Data? = nil
    
    init() {
        loadTasks()
    }
    
    // MARK: - Public API
    
    /// Add a new generation task to the queue
    @MainActor
    func enqueue(input: String, mode: InputMode, promptID: UUID? = nil, themeID: String = "wechat-green") -> GenerationTask {
        let task = GenerationTask(
            id: UUID(),
            inputText: input,
            inputMode: mode,
            promptID: promptID,
            createdAt: Date(),
            status: .pending,
            result: nil,
            errorMessage: nil,
            elapsedSeconds: 0,
            selectedThemeID: themeID
        )
        
        tasks.append(task)
        updatePendingTasks()
        return task
    }
    
    /// Cancel a specific task
    @MainActor
    func cancelTask(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }),
              tasks[index].status == .running || tasks[index].status == .pending else { return }
        
        tasks[index].status = .cancelled
    }
    
    /// Delete completed/failed/cancelled tasks
    @MainActor
    func deleteTask(id: UUID) {
        tasks.removeAll { $0.id == id }
        newlyCompletedIDs.remove(id)
    }
    
    /// Clear all done tasks
    @MainActor
    func clearDoneTasks() {
        tasks.removeAll { $0.status != .running }
        newlyCompletedIDs.removeAll()
    }
    
    /// Mark completed tasks as read (user has viewed the result)
    @MainActor
    func markAsRead() {
        newlyCompletedIDs.removeAll()
    }
    
    // MARK: - Internal (called by GenerationService via delegate)
    
    @MainActor
    internal func startTask(_ id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].status = .running
        tasks[index].elapsedSeconds = 0
        
        // Start timer
        Task {
            while !Task.isCancelled,
                  let idx = tasks.firstIndex(where: { $0.id == id }),
                  tasks[idx].status == .running {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    if let i = tasks.firstIndex(where: { $0.id == id }) {
                        tasks[i].elapsedSeconds += 1
                    }
                }
            }
        }
    }
    
    @MainActor
    internal func completeTask(_ id: UUID, result: GenerationResult) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].status = .completed
        tasks[index].result = result
        newlyCompletedIDs.insert(id)
    }
    
    @MainActor
    internal func failTask(_ id: UUID, error: Error) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].status = .failed
        tasks[index].errorMessage = error.localizedDescription
    }
    
    @MainActor
    internal func advancePendingTasks() {
        updatePendingTasks()
    }
    
    // MARK: - Queue Management
    
    private func updatePendingTasks() {
        // Run next pending task if we have capacity
        let runningCount = tasks.filter { $0.status == .running }.count
        if runningCount < concurrentLimit {
            if let pendingIndex = tasks.firstIndex(where: { $0.status == .pending }) {
                tasks[pendingIndex].status = .running
                
                // Execute immediately on current thread (background)
                Task.detached(priority: .userInitiated) { [weak self] in
                    guard let self = self else { return }
                    let task = self.tasks[pendingIndex]
                    
                    // Import settings for API access
                    let settings = AppSettings()
                    let service = GenerationService(settings: settings)
                    
                    await self.startTask(task.id)
                    
                    do {
                        let genResult = try await self.executeTask(task, service: service)
                        await self.completeTask(task.id, result: genResult)
                    } catch is CancellationError {
                        await self.cancelTask(id: task.id)
                    } catch {
                        await self.failTask(task.id, error: error)
                    }
                    
                    await self.advancePendingTasks()
                }
            }
        }
    }
    
    private func executeTask(_ task: GenerationTask, service: GenerationService) async throws -> GenerationResult {
        switch task.inputMode {
        case .aiGenerate:
            return try await service.generate(from: task.inputText)
        case .directConvert:
            // Direct conversion is synchronous
            return try await convertFromMarkdown(task.inputText)
        }
    }
    
    private func convertFromMarkdown(_ text: String) async throws -> GenerationResult {
        // Simulate async for queue compatibility
        try await Task.sleep(nanoseconds: 500_000_000)
        
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var title = ""
        var content = text
        
        if let firstLine = lines.first {
            let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                title = String(trimmed.dropFirst(2))
                content = lines.dropFirst().joined(separator: "\n")
            } else if trimmed.hasPrefix("#") {
                title = String(trimmed.dropFirst(1))
                content = lines.dropFirst().joined(separator: "\n")
            }
        }
        
        return GenerationResult(title: title, summary: "", content: content, coverImagePrompt: "")
    }
    
    // MARK: - Persistence
    
    private func loadTasks() {
        // Keep it simple — don't persist across app launches
        // Tasks are transient; historical results live in ContentView
    }
    
    private func saveTasks() {
        // Transient only
    }
}
