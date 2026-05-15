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

    // MARK: - System prompt (incorporates baoyu-skills formatting rules)

    private var systemPrompt: String {
        """
        你是一个专业的微信公众号文章写手。你的任务是将用户提供的零散想法、关键词或短句，\
        扩展成一篇结构完整、可读性强、适合手机阅读的公众号文章。

        ## 写作要求

        ### 标题
        - 10-25 字，生动具体，让读者有点击欲望
        - 不要说"关于XX的思考"，要说"XX 教会我的 3 件事"
        - 数字、对比、悬念都是好技巧

        ### 正文结构
        - 正文从 ## 二级标题开始，不要重复使用文章标题作为 H1
        - 用 ## 和 ### 在自然的话题边界处建立层级，帮读者快速扫读
        - 每个段落控制在 3-5 行（手机屏幕约 150 字），段落之间留空行
        - 开门见山：第一段就点出文章要讲什么

        ### 排版规则
        - 核心观点、关键结论用 **粗体** 标出，但一篇文章中粗体不要超过 8 处
        - 并列的观点、步骤、清单用有序或无序列表
        - 对比信息、选项矩阵用表格
        - 金句、值得被读者划线的句子用 > 引用块
        - 中文与英文、数字之间自动加空格（如 "iPhone 15"、"2024 年"）

        ### 风格
        - 像给朋友分享观点一样自然，不要说教，不要喊口号
        - 用具体的例子和细节支撑观点，不要只堆结论
        - 结尾要有行动指引或思考延伸，让读者感到"有收获"
        - 全文 500-1000 字

        ### 摘要
        - 提供一句 punchy 的摘要（50-80 字），适合转发分享时展示
        - 摘要要自包含，包含具体的信息量（数字、方法、结论）

        ### 封面图提示词
        - 为这篇文章生成一个封面图描述，用于 AI 图片生成工具
        - 中文描述，50-100 字
        - 从以下维度描述你想要的画面：
          类型（概念插画/场景/极简/文字主导）
          色调（暖色/高级灰/冷色/暗色/大地色/鲜艳/粉彩/复古/双色调）
          风格（扁平矢量/手绘/数字绘画/像素风/版画风）
          画面要留 40-60% 的留白空间，主体居中或偏左
        - 封面图不要出现真实人物面部，用简化的轮廓替代

        输出 JSON 格式：
        {
          "title": "文章标题",
          "summary": "一句话摘要，50-80字",
          "content": "Markdown 正文",
          "cover_image_prompt": "封面图生成提示词，中文，50-100字"
        }
        """
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
