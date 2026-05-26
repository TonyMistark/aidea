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
    @Published var customPrompt: String {
        didSet { UserDefaults.standard.set(customPrompt, forKey: "custom_prompt") }
    }

    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "api_key") ?? ""
        self.apiBaseURL = UserDefaults.standard.string(forKey: "api_base_url") ?? "https://api.openai.com/v1"
        self.modelName = UserDefaults.standard.string(forKey: "model_name") ?? "gpt-4o"

        let defaultPrompt = Self.defaultPrompt
        self.customPrompt = UserDefaults.standard.string(forKey: "custom_prompt") ?? defaultPrompt
    }

    var isConfigured: Bool { !apiKey.isEmpty }

    /// 恢复默认 AI prompt
    func resetPromptToDefault() {
        customPrompt = Self.defaultPrompt
    }

    /// 内置默认 AI system prompt
    static let defaultPrompt = """
    你是一个专业的微信公众号文章写手。你的任务是将用户提供的零散想法、关键词或短句，扩展成一篇结构完整、可读性强、适合手机阅读的公众号文章。

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
