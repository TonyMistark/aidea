import SwiftUI

enum InputMode: String, CaseIterable {
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
    @State private var showTaskList = false
    @State private var currentTaskID: UUID?

    private var service: GenerationService {
        GenerationService(settings: settings)
    }

    var body: some View {
        NavigationStack {
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
                    .contentShape(Rectangle())
                    .onTapGesture { dismissKeyboard() }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Aidear")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // Task list button
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showTaskList = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: taskManager.runningCount > 0
                                  ? "clock.arrow.circlepath" : "list.bullet")
                                .foregroundColor(taskManager.runningCount > 0 ? .blue : .secondary)
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
            .sheet(isPresented: $showTaskList) {
                taskListSheet
            }
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
                themeID: ThemeManager.shared.activeTheme.id,
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
                Text(ThemeManager.shared.activeTheme.name)
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

    private var themePickerSheet: some View {
        NavigationStack {
            List {
                ForEach(ThemeManager.shared.themes) { theme in
                    Button {
                        ThemeManager.shared.setTheme(id: theme.id)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(theme.previewColors.primary))
                                    .frame(width: 36, height: 36)
                                Circle()
                                    .fill(Color(theme.previewColors.secondary))
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
                            
                            if theme.id == ThemeManager.shared.activeTheme.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(theme.previewColors.primary))
                            }
                        }
                        .padding(.vertical, 4)
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

        let task = taskManager.enqueue(
            input: inputText,
            mode: .aiGenerate,
            promptID: settings.activePromptID
        )
        currentTaskID = task.id

        // Observe the new task for results via MainActor publishing
        Task { @MainActor in
            // Poll task status — if running becomes completed/failed, update UI
            let interval = 0.5
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                
                guard let t = taskManager.tasks.first(where: { $0.id == task.id }) else { break }
                
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

        let task = taskManager.enqueue(
            input: inputText,
            mode: .directConvert,
            promptID: settings.activePromptID
        )
        currentTaskID = task.id

        // Observe for immediate completion (direct convert is fast)
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000)
                
                guard let t = taskManager.tasks.first(where: { $0.id == task.id }) else { break }
                
                switch t.status {
                case .completed:
                    if let res = t.result {
                        result = res
                        withAnimation(.easeInOut(duration: 0.25)) {
                            inputExpanded = false
                        }
                        taskManager.markAsRead()
                    }
                case .failed:
                    errorMessage = t.errorMessage ?? "转换失败"
                default:
                    break
                }
            }
            currentTaskID = nil
        }
    }

    // MARK: - Task List

    private var taskListSheet: some View {
        NavigationStack {
            Group {
                if taskManager.tasks.isEmpty {
                    ContentUnavailableView(
                        "暂无任务",
                        systemImage: "clock.badge.exclamationmark",
                        description: Text("点击「开始AI创作」即可发起生成任务")
                    )
                } else {
                    List {
                        ForEach(taskManager.tasks) { task in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(task.title)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(task.elapsedSeconds)s")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                HStack {
                                    Text(task.statusBadgeText)
                                        .font(.caption2)
                                        .foregroundColor(task.status == .failed ? .red : (task.status == .running ? .blue : .secondary))
                                    
                                    Spacer()
                                    
                                    Button("查看") {
                                        // Show result inline in main content
                                        if let res = task.result {
                                            result = res
                                            showTaskList = false
                                            withAnimation(.easeInOut(duration: 0.25)) {
                                                inputExpanded = false
                                            }
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    .disabled(task.status != .completed || task.result == nil)
                                    
                                    if task.status == .running {
                                        Menu("操作") {
                                            Button("取消") { taskManager.cancelTask(id: task.id) }
                                        }
                                    }
                                    if task.status != .running && task.status != .pending {
                                        Menu("操作") {
                                            Button("删除") { taskManager.deleteTask(id: task.id) }
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.insetGrouped)
                    
                    // Clear button for done tasks
                    if taskManager.tasks.contains(where: { $0.status != .running }) {
                        Button("清理已完成的任务") {
                            taskManager.clearDoneTasks()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationTitle("任务列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showTaskList = false }
                }
            }
        }
    }
}
