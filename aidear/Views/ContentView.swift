import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

enum InputMode: String, CaseIterable, Codable {
    case aiGenerate = "AI 创作"
    case directConvert = "直接转换"
}

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var taskManager = TaskManager()
    @State private var inputText = ""
    @State private var isGenerating = false
    @State private var result: GenerationResult?
    @State private var showSettings = false
    @State private var errorMessage: String?
    @State private var showCoverPrompt = false
    @State private var webContentHeight: CGFloat = 100
    @State private var copyHTMLTrigger = 0
    @State private var inputExpanded = true
    @State private var inputMode: InputMode = .aiGenerate
    @State private var showCancelAlert = false
    @State private var elapsedSeconds = 0
    @State private var pastePreview = ""
    @State private var showPasteSheet = false
    @State private var showThemePicker = false
    @State private var showDrawer = false
    @State private var currentTaskID: UUID?
    @State private var taskToDelete: UUID?
    @State private var watchHandle: Task<Void, Never>?

    private var service: GenerationService {
        GenerationService(settings: settings)
    }

    var body: some View {
        NavigationStack {
            ZStack {
            VStack(spacing: 0) {
                if result != nil {
                    collapsedInputBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                ScrollView {
                    VStack(spacing: 20) {
                        if result == nil {
                            modePicker
                            inputSection
                            generateButton
                        } else if inputExpanded {
                            modePicker
                            inputSection
                            generateButton
                        }

                        if let errorMessage {
                            errorBanner(errorMessage)
                        }
                        if let result {
                            resultSection(result)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, result != nil && !inputExpanded ? 16 : 16)
                    .background(
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { dismissKeyboard() }
                    )
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Aidear")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { withAnimation(.easeInOut(duration: 0.2)) { showDrawer = true } } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal")
                                .fontWeight(.semibold)
                            if taskManager.runningCount > 0 {
                                Text("\(taskManager.runningCount)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .clipShape(Capsule())
                            }
                            if taskManager.unreadCompletedCount > 0 {
                                Text("\(taskManager.unreadCompletedCount)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showPasteSheet) {
                pastePreviewSheet
            }
            .sheet(isPresented: $showThemePicker) {
                themePickerSheet
            }
            // Left drawer overlay
            drawerOverlay
            } // ZStack
        }
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        Picker("模式", selection: $inputMode) {
            ForEach(InputMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(inputMode == .aiGenerate ? "写下你的想法" : "粘贴 Markdown 文本")
                .font(.headline)
                .foregroundColor(.secondary)

            TextEditor(text: $inputText)
                .frame(minHeight: result != nil ? 100 : 150)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
                .overlay(alignment: .topLeading) {
                    if inputText.isEmpty {
                        Text(inputMode == .aiGenerate
                             ? "例如：今天和同事聊到远程办公的效率问题，我觉得关键不在工具，而在信任..."
                             : "例如：## 我的观点\n\n内容...\n\n- 要点一\n- 要点二")
                            .foregroundColor(Color(.systemGray3))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - Collapsed Input Bar

    private var collapsedInputBar: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                inputExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "pencil.line")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(inputText.isEmpty
                     ? (inputMode == .aiGenerate ? "点击编辑你的想法..." : "点击编辑 Markdown 文本...")
                     : inputText)
                    .lineLimit(1)
                    .font(.subheadline)
                    .foregroundColor(inputText.isEmpty ? Color(.systemGray3) : .primary)
                Spacer()
                Image(systemName: inputExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        VStack(spacing: 8) {
            // Paste format button (only in direct convert mode)
            if inputMode == .directConvert {
                pasteFormatButton
                    .transition(.opacity)
            }

            primaryGenerateButton
        }
    }

    /// "粘贴保留格式"按钮 — 在直接转换模式下，把剪贴板中的富文本（网页/Word/微信）转成 Markdown
    private var pasteFormatButton: some View {
        Button {
            presentPasteConfirmation()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "doc.on.clipboard")
                    .font(.caption)
                Text("粘贴保留格式")
                    .font(.subheadline)
            }
            .foregroundColor(.blue)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    /// 主生成/转换按钮
    private var primaryGenerateButton: some View {
        Button {
            if isGenerating {
                showCancelAlert = true
            } else {
                handleAction()
            }
        } label: {
            HStack(spacing: 8) {
                if isGenerating {
                    ProgressView()
                        .tint(.white)
                    Text("AI创作中(\(elapsedSeconds)s)")
                } else if inputMode == .aiGenerate {
                    Image(systemName: "sparkles")
                    Text(result != nil ? "重新生成" : "开始AI创作")
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text(result != nil ? "重新转换" : "转换")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isGenerating
                    ? Color.orange
                    : (inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.blue)
            )
            .cornerRadius(12)
        }
        .disabled(!isGenerating && inputText.trimmingCharacters(in: .whitespaces).isEmpty)
        .alert("取消生成？", isPresented: $showCancelAlert) {
            Button("继续生成", role: .cancel) { }
            Button("取消生成", role: .destructive) {
                if let taskId = currentTaskID {
                    taskManager.cancelTask(id: taskId)
                }
                isGenerating = false
                currentTaskID = nil
            }
        } message: {
            Text("当前正在生成文章，确定要取消吗？")
        }
    }

    // MARK: - Error

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
    }

    // MARK: - Result Section

    private func resultSection(_ result: GenerationResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()

            // Title — selectable & copyable
            if !result.title.isEmpty {
                Text(result.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .textSelection(.enabled)
            }

            // Summary
            if !result.summary.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Text("摘要")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.7))
                        .cornerRadius(4)

                    Text(result.summary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineSpacing(4)

                    Spacer()

                    Button {
                        UIPasteboard.general.string = result.summary
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }

            // Cover image prompt
            if !result.coverImagePrompt.isEmpty {
                coverPromptSection(result.coverImagePrompt)
            }

            // Action buttons
            HStack(spacing: 12) {
                copyButton(result)
                shareButton(result)
            }

            // Theme switcher
            themeSwitcherRow

            Divider()

            // Article content — rendered as styled HTML via selected theme
            MarkdownWebView(
                markdown: result.content,
                themeID: currentTaskThemeID(),
                onHeightChange: { h in
                    webContentHeight = h
                },
                copyTrigger: copyHTMLTrigger
            )
            .frame(height: max(webContentHeight, 100))
        }
    }

    // MARK: - Cover Prompt

    private func coverPromptSection(_ prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { showCoverPrompt.toggle() }
            } label: {
                HStack {
                    Image(systemName: "photo.artframe")
                    Text("封面图提示词")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: showCoverPrompt ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(.primary)
            }

            if showCoverPrompt {
                Text(prompt)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                Button {
                    UIPasteboard.general.string = prompt
                } label: {
                    Label("复制提示词", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Action Buttons

    private func copyButton(_ result: GenerationResult) -> some View {
        Button {
            copyHTMLTrigger += 1
        } label: {
            Label("复制微信格式", systemImage: "doc.on.doc")
                .font(.subheadline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private func shareButton(_ result: GenerationResult) -> some View {
        let shareText = """
        # \(result.title)

        > \(result.summary)

        \(result.content)
        """
        return ShareLink(item: shareText) {
            Label("分享", systemImage: "square.and.arrow.up")
                .font(.subheadline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Theme Switcher

    private var themeSwitcherRow: some View {
        Button {
            showThemePicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "paintpalette")
                    .font(.caption)
                Text(currentTaskThemeID() == ThemeManager.shared.activeTheme.id
                     ? ThemeManager.shared.activeTheme.name
                     : getThemeName(for: currentTaskThemeID()))
                    .font(.subheadline)
                Spacer()
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    /// Get display name for a theme ID (used for per-article themes)
    private func getThemeName(for id: String) -> String {
        ThemeManager.shared.themes.first(where: { $0.id == id })?.name ?? "自定义"
    }

    private var themePickerSheet: some View {
        NavigationStack {
            List {
                ForEach(ThemeManager.shared.themes) { theme in
                    Button {
                        ThemeManager.shared.setTheme(id: theme.id)
                        // If viewing a result, also update that task's theme
                        if let taskId = currentTaskID {
                            taskManager.setTaskTheme(id: taskId, themeID: theme.id)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: theme.previewColors.primary))
                                    .frame(width: 36, height: 36)
                                Circle()
                                    .fill(Color(hex: theme.previewColors.secondary))
                                    .frame(width: 24, height: 24)
                                    .offset(x: 10, y: 10)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(theme.name)
                                    .font(.subheadline)
                                Text(theme.description)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if theme.id == currentTaskThemeID() {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: theme.previewColors.primary))
                                        .frame(width: 22, height: 22)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .background(
                            theme.id == currentTaskThemeID()
                                ? Color(hex: theme.previewColors.primary).opacity(0.08)
                                : Color.clear
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("选择主题")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showThemePicker = false }
                }
            }
        }
    }

    // MARK: - Rich Text Paste

    /// 弹出预览 Sheet，展示从剪贴板解析出的 Markdown，用户确认后填入输入框
    private func presentPasteConfirmation() {
        guard let markdown = RichTextParser.parseClipboardAsMarkdown(),
              !markdown.trimmingCharacters(in: .whitespaces).isEmpty
        else {
            errorMessage = "剪贴板中没有检测到格式文本，请直接粘贴 Markdown 或切换到 AI 创作模式"
            return
        }
        pastePreview = markdown
        showPasteSheet = true
    }

    private var pastePreviewSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("已检测到的 Markdown 内容")
                        .font(.headline)
                        .padding(.horizontal, 16)

                    Text(pastePreview)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal, 16)

                    // Word count
                    let charCount = pastePreview.count
                    Text("\(charCount) 字")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)

                    Divider()

                    Button {
                        // Confirm: set as input text
                        inputText = pastePreview
                        result = nil
                        errorMessage = nil
                        showPasteSheet = false
                    } label: {
                        Label("确认替换输入框内容", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)

                    Button {
                        // Discard: cancel
                        showPasteSheet = false
                    } label: {
                        Label("取消", systemImage: "xmark.circle.fill")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("粘贴保留格式")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Actions

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }

    private func handleAction() {
        switch inputMode {
        case .aiGenerate:
            generate()
        case .directConvert:
            convert()
        }
    }

    private func generate() {
        errorMessage = nil
        showCoverPrompt = false

        taskManager.enqueue(
            input: inputText,
            mode: .aiGenerate,
            promptID: settings.activePromptID,
            themeID: ThemeManager.shared.activeTheme.id
        )
        // Clear for next conversation — task runs in background
        inputText = ""
        result = nil
        isGenerating = false
        currentTaskID = nil
    }

    private func watchTask(id: UUID) {
        watchHandle?.cancel()
        watchHandle = Task { @MainActor in
            let interval = 0.5
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

                guard let t = taskManager.tasks.first(where: { $0.id == id }) else { break }

                switch t.status {
                case .running:
                    isGenerating = true
                    elapsedSeconds = t.elapsedSeconds
                case .completed:
                    if let res = t.result {
                        result = res
                        withAnimation(.easeInOut(duration: 0.25)) {
                            inputExpanded = false
                        }
                        taskManager.markAsRead()
                    }
                    isGenerating = false
                case .failed:
                    errorMessage = t.errorMessage ?? "生成失败"
                    isGenerating = false
                case .cancelled:
                    isGenerating = false
                default:
                    break
                }
            }
            isGenerating = false
            currentTaskID = nil
        }
    }

    private func convert() {
        errorMessage = nil
        result = nil
        showCoverPrompt = false

        taskManager.enqueue(
            input: inputText,
            mode: .directConvert,
            promptID: settings.activePromptID,
            themeID: ThemeManager.shared.activeTheme.id
        )
        // Clear for next conversation — result available in drawer
        inputText = ""
        isGenerating = false
    }

    // MARK: - Task List

    /// Get theme ID for current result (per-article theme if available, else global)
    private func currentTaskThemeID() -> String {
        guard let taskId = currentTaskID,
              let task = taskManager.tasks.first(where: { $0.id == taskId }) else {
            return ThemeManager.shared.activeTheme.id
        }
        return task.selectedThemeID
    }

    // MARK: - Drawer

    private var drawerOverlay: some View {
        ZStack {
            if showDrawer {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { showDrawer = false } }
                HStack {
                    drawerContent
                        .frame(width: 280)
                        .background(Color(.systemBackground))
                        .transition(.move(edge: .leading))
                    Spacer()
                }
            }
        }
    }

    private var drawerContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("对话")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // New dialog button
            Button {
                selectNewDialog()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.body)
                    Text("新对话")
                        .font(.subheadline)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(currentTaskID == nil ? Color.blue.opacity(0.1) : Color.clear)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            if taskManager.tasks.isEmpty {
                Spacer()
                Text("暂无对话")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("开始AI创作后自动出现在这里")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(taskManager.tasks) { task in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(task.title)
                                    .font(.subheadline)
                                    .fontWeight(currentTaskID == task.id ? .semibold : .regular)
                                    .lineLimit(1)
                                Spacer()
                            }
                            HStack {
                                Text(task.statusBadgeText)
                                    .font(.caption2)
                                    .foregroundColor(task.status == .failed ? .red
                                        : (task.status == .running ? .blue : .secondary))
                                Spacer()
                                if task.status == .running {
                                    Button("取消") {
                                        taskManager.cancelTask(id: task.id)
                                    }
                                    .font(.caption2)
                                    .buttonStyle(.plain)
                                    .foregroundColor(.secondary)
                                    Button("取消并删除") {
                                        taskToDelete = task.id
                                    }
                                    .font(.caption2)
                                    .buttonStyle(.plain)
                                    .foregroundColor(.red)
                                } else {
                                    Button {
                                        taskToDelete = task.id
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption2)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                        .contentShape(Rectangle())
                        .onTapGesture { selectTask(task) }
                        .background(
                            currentTaskID == task.id
                                ? Color.blue.opacity(0.08)
                                : Color.clear
                        )
                        .cornerRadius(6)
                    }
                }
                .listStyle(.plain)
            }
        }
        .alert("确认删除", isPresented: Binding(
            get: { taskToDelete != nil },
            set: { if !$0 { taskToDelete = nil } }
        )) {
            Button("取消", role: .cancel) { taskToDelete = nil }
            Button("删除", role: .destructive) {
                if let id = taskToDelete {
                    withAnimation { taskManager.deleteTask(id: id) }
                    taskToDelete = nil
                }
            }
        } message: {
            Text("此操作不可撤销")
        }
    }

    private func selectNewDialog() {
        withAnimation(.easeInOut(duration: 0.2)) { showDrawer = false }
        currentTaskID = nil
        result = nil
        errorMessage = nil
        isGenerating = false
        inputText = ""
        inputExpanded = true
    }

    private func selectTask(_ task: GenerationTask) {
        withAnimation(.easeInOut(duration: 0.2)) { showDrawer = false }
        inputText = task.inputText
        inputMode = task.inputMode
        errorMessage = nil
        currentTaskID = task.id

        switch task.status {
        case .completed:
            result = task.result
            isGenerating = false
            withAnimation(.easeInOut(duration: 0.25)) { inputExpanded = false }
        case .running:
            result = nil
            isGenerating = true
            elapsedSeconds = task.elapsedSeconds
            inputExpanded = true
            watchTask(id: task.id)
        case .failed:
            result = nil
            isGenerating = false
            errorMessage = task.errorMessage
            inputExpanded = true
        case .cancelled, .pending:
            result = nil
            isGenerating = false
            inputExpanded = true
        }
    }
}
