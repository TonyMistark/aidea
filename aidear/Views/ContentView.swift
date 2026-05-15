import SwiftUI

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

    private var service: GenerationService {
        GenerationService(settings: settings)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    inputSection
                    generateButton
                    if let errorMessage {
                        errorBanner(errorMessage)
                    }
                    if let result {
                        resultSection(result)
                    }
                }
                .padding()
                .contentShape(Rectangle())
                .onTapGesture { dismissKeyboard() }
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

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("写下你的想法")
                .font(.headline)
                .foregroundColor(.secondary)

            TextEditor(text: $inputText)
                .frame(minHeight: 150)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
                .overlay(alignment: .topLeading) {
                    if inputText.isEmpty {
                        Text("例如：今天和同事聊到远程办公的效率问题，我觉得关键不在工具，而在信任...")
                            .foregroundColor(Color(.systemGray3))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            Task { await generate() }
        } label: {
            HStack(spacing: 8) {
                if isGenerating {
                    ProgressView()
                        .tint(.white)
                    Text("AI 正在创作...")
                } else {
                    Image(systemName: "sparkles")
                    Text("AI 生成文章")
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
            Text(result.title)
                .font(.title2)
                .fontWeight(.bold)

            // Summary
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

            // Article content — rendered as WeChat-styled HTML via md2wechat CSS
            MarkdownWebView(
                markdown: result.content,
                onHeightChange: { h in
                    webContentHeight = h
                },
                copyTrigger: copyHTMLTrigger
            )
            .frame(height: max(webContentHeight, 100))

            Divider()

            // Cover image prompt
            coverPromptSection(result.coverImagePrompt)

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

    private func generate() async {
        isGenerating = true
        errorMessage = nil
        result = nil
        showCoverPrompt = false

        do {
            result = try await service.generate(from: inputText)
        } catch {
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }
}
