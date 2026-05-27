import Foundation

struct GenerationResult {
    let title: String
    let summary: String
    let content: String
    let coverImagePrompt: String
}

final class GenerationService {
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func generate(from input: String) async throws -> GenerationResult {
        guard settings.isConfigured else {
            return try await mockGenerate(from: input)
        }
        return try await remoteGenerate(from: input)
    }

    // MARK: - Remote AI generation

    private func remoteGenerate(from input: String) async throws -> GenerationResult {
        let url = URL(string: "\(settings.apiBaseURL)/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 90

        let body: [String: Any] = [
            "model": settings.modelName,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": input]
            ],
            "temperature": 0.8,
            "response_format": ["type": "json_object"]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let choices = json?["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let contentStr = message["content"] as? String,
              let contentData = contentStr.data(using: .utf8),
              let result = try? JSONDecoder().decode(GenerationResultJSON.self, from: contentData)
        else {
            throw NSError(domain: "Aidear", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "AI 返回格式异常，请重试"])
        }

        return GenerationResult(
            title: result.title,
            summary: result.summary,
            content: result.content,
            coverImagePrompt: result.cover_image_prompt
        )
    }

    // MARK: - System prompt (from user settings)

    private var systemPrompt: String {
        settings.activePromptContent
    }

    // MARK: - Mock generation (for demo without API key)

    private func mockGenerate(from input: String) async throws -> GenerationResult {
        try await Task.sleep(nanoseconds: 2_000_000_000)

        let title = mockTitle(from: input)
        let summary = mockSummary(from: input)
        let content = mockContent(from: input, title: title)
        let coverPrompt = mockCoverPrompt(from: input, title: title)

        return GenerationResult(
            title: title,
            summary: summary,
            content: content,
            coverImagePrompt: coverPrompt
        )
    }

    private func mockTitle(from input: String) -> String {
        let titles = [
            "从碎片想法到深度思考，我用了这 3 个方法",
            "别让你的灵感溜走：普通人的表达进阶之路",
            "写给只想写点东西的你：AI 时代的写作新可能",
            "与其纠结文笔，不如先把想法写出来",
            "用 AI 写作 30 天后，我发现了表达的真正意义"
        ]
        return titles.randomElement() ?? input
    }

    private func mockSummary(from input: String) -> String {
        let summaries = [
            "零散的想法也能变成好文章。这篇文章分享了如何借助 AI，将日常灵感转化为结构清晰的文字，让表达不再困难。",
            "不是写作者才能写作。本文介绍了一种新的创作方式：你只需要说出想法，AI 帮你完成从碎片到文章的跨越。"
        ]
        return summaries.randomElement()!
    }

    private func mockContent(from input: String, title: String) -> String {
        let intro = input.isEmpty
            ? "每个人心里都住着一个写作者，只是缺少一把打开表达的钥匙。"
            : "你写下的这些想法，正是一篇好文章最好的种子。"

        return """
        *（模拟生成。配置 API Key 后获得真实 AI 生成内容。）*

        ## 写在前面

        \(intro)

        > 你输入的想法：\(input.isEmpty ? "（等待你的灵感）" : input)

        ## 为什么碎片想法也值得被认真对待

        你可能在通勤路上突然想到一个好点子，可能在会议中冒出一个新思路，也可能在深夜被某个念头击中。**这些碎片化的思考，往往因为 "没时间整理" 而消失在忙碌里。**

        但如果你能抓住它们呢？

        写作不是为了成为作家。**写作是思考的工具。** 当你试图把模糊的想法写清楚时，你会发现——原来自己并没有真的想明白。写作的过程，就是逼自己把思路理清楚的过程。

        ## 从碎片到文章的三个关键

        ### 1. 先捕捉，别筛选

        灵感来的时候，不要判断它 "值不值得写"。**先记下来。** 让 AI 帮你判断哪些可以扩展成文章。很多看似平凡的想法，经过 AI 的扩充和梳理，会呈现出你意想不到的深度。

        ### 2. 先完成，再完美

        不要追求第一稿就完美。把你的零散想法倒给 AI，让它帮你生成初稿。有了初稿之后，你再修改、补充、调整——**有东西可改比从零开始容易十倍。**

        ### 3. 保持真实

        AI 可以帮你润色和扩展，但你的观点、你的经历、你的态度才是文章的灵魂。**读者追随的不是完美的文笔，而是真实的人。**

        ## 开始你的第一次创作

        \(input.isEmpty
            ? "下次打开 Aidear，试着输入一些你的想法。哪怕只是一个关键词、一句感慨，AI 都能帮你展开成一篇完整的文章。"
            : "你的想法已经有了雏形。点击生成按钮，让 AI 帮你把它变成一篇完整的文章。")

        ---

        *Aidear 模拟生成 | 配置 API Key 后获得真实 AI 写作体验*
        """
    }

    private func mockCoverPrompt(from input: String, title: String) -> String {
        let prompts = [
            "概念插画风格，暖色调。画面主体为一支发光的笔在纸上书写，光线扩散成星空状。背景留白 50%，文字叠加在右上方。扁平矢量风格，不要人物面部。",
            "极简场景风格，大地色系。画面为一张木质书桌上放着打开的笔记本和一杯咖啡，窗外有晨光洒入。留白 50%，数字绘画质感。",
            "文字主导类型，高级灰色调。画面中央为手写体大标题，周围散落着关键词碎片，碎片逐渐聚拢成完整句子。版画风格，留白 40%。"
        ]
        return prompts.randomElement()!
    }
}

// MARK: - JSON model

private struct GenerationResultJSON: Decodable {
    let title: String
    let summary: String
    let content: String
    let cover_image_prompt: String
}
