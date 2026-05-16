import SwiftUI

enum InputMode: String, CaseIterable {
    case aiGenerate = "AI 创作"
    case directConvert = "直接转换"
}

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
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
        Button {
            Task { await handleAction() }
        } label: {
            HStack(spacing: 8) {
                if isGenerating {
                    ProgressView()
                        .tint(.white)
                    Text("AI 正在创作...")
                } else if inputMode == .aiGenerate {
                    Image(systemName: "sparkles")
                    Text(result != nil ? "重新生成" : "AI 生成文章")
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text(result != nil ? "重新转换" : "转换")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.blue)
            .cornerRadius(12)
        }
        .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isGenerating)
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

            // Title
            if !result.title.isEmpty {
                Text(result.title)
                    .font(.title2)
                    .fontWeight(.bold)
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
                }
            }

            // Article content — rendered as WeChat-styled HTML via md2wechat CSS
            MarkdownWebView(
                markdown: result.content,
                onHeightChange: { h in
                    webContentHeight = h
                },
                copyTrigger: copyHTMLTrigger
            )
            .frame(height: max(webContentHeight, 100))

            // Cover image prompt
            if !result.coverImagePrompt.isEmpty {
                Divider()
                coverPromptSection(result.coverImagePrompt)
            }

            // Action buttons
            HStack(spacing: 12) {
                copyButton(result)
                shareButton(result)
            }
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

    // MARK: - Actions

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }

    private func handleAction() async {
        switch inputMode {
        case .aiGenerate:
            await generate()
        case .directConvert:
            convert()
        }
    }

    private func generate() async {
        isGenerating = true
        errorMessage = nil
        result = nil
        showCoverPrompt = false

        do {
            result = try await service.generate(from: inputText)
            withAnimation(.easeInOut(duration: 0.25)) {
                inputExpanded = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }

    private func convert() {
        errorMessage = nil
        result = nil
        showCoverPrompt = false

        let lines = inputText.split(separator: "\n", omittingEmptySubsequences: false)
        var title = ""
        if let firstLine = lines.first?.trimmingCharacters(in: .whitespaces),
           firstLine.hasPrefix("# ") {
            title = String(firstLine.dropFirst(2))
        } else if let firstLine = lines.first?.trimmingCharacters(in: .whitespaces),
                  firstLine.hasPrefix("#") {
            title = String(firstLine.dropFirst(1))
        }

        result = GenerationResult(
            title: title,
            summary: "",
            content: inputText,
            coverImagePrompt: ""
        )

        withAnimation(.easeInOut(duration: 0.25)) {
            inputExpanded = false
        }
    }
}
