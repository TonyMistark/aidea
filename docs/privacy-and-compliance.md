# 隐私政策与合规文档

## 一、隐私政策

### 为什么必须有

- App Store 审核的硬性要求（Guideline 5.1.1）
- 必须是一个可以公开访问的 URL
- 必须说明你收集了什么数据、怎么用、和谁分享

### 隐私政策模板

以下内容可以直接使用，把 `[YOUR_EMAIL]` 和 `[YOUR_NAME]` 替换成你自己的：

---

# 隐私政策

最后更新日期：[当前日期]

## 简介

Aidear（"我们"）重视你的隐私。本隐私政策说明我们如何收集、使用和保护你的信息。

## 我们收集的信息

### 你主动提供的信息

- **文本内容**：你在 App 中输入的文字内容会被发送到 AI 服务（OpenAI API）以生成文章。这些内容仅用于当次生成请求，不会被我们存储。

### 自动收集的信息

- **匿名用户标识**：我们使用 Sign in with Apple 生成匿名用户 ID，仅用于防止 API 滥用和计数，不与你的真实身份关联。
- **使用数据**：我们可能收集匿名的使用统计（如生成次数），仅用于改善服务质量。

## 我们如何使用信息

- **生成文章**：你的输入文本被发送到 OpenAI API 进行 AI 处理，生成结构化的文章。
- **服务改进**：匿名的使用统计数据帮助我们了解 App 的使用情况。

## 数据存储

我们不存储你的输入内容和生成的文章。AI 生成过程完全在请求-响应的流程中完成，处理完成后不保留副本。

## 第三方服务

我们使用以下第三方服务：

| 服务 | 用途 | 隐私政策 |
|---|---|---|
| OpenAI API | AI 文本生成 | [https://openai.com/policies/privacy-policy](https://openai.com/policies/privacy-policy) |
| Cloudflare | API 代理与加速 | [https://www.cloudflare.com/privacypolicy/](https://www.cloudflare.com/privacypolicy/) |

## 数据安全

- 所有网络通信使用 HTTPS 加密
- 我们不会向第三方出售你的数据
- 我们不会使用你的数据训练 AI 模型

## 你的权利

你可以随时在 App 内退出登录并删除你的匿名用户标识。

## 儿童隐私

本 App 不面向 13 岁以下儿童。我们不会有意收集儿童的个人信息。

## 联系我们

如有隐私相关问题，请联系：[YOUR_EMAIL]

---

### 发布隐私政策

最简单的发布方式：

**方案：GitHub Pages**

```bash
# 1. 创建仓库
# 在 GitHub 创建公开仓库，比如 yourname/aidear-privacy

# 2. 添加隐私政策文件
# 在仓库根目录创建 index.html，把上面的隐私政策放进去

# 3. 启用 GitHub Pages
# Settings → Pages → Source: Deploy from a branch → main → Save

# 4. 获取 URL
# https://yourname.github.io/aidear-privacy
```

然后把 `https://yourname.github.io/aidear-privacy` 填入 App Store Connect。

> 如果不想建站，也可以用 Notion 发布一个公开页面，把链接填进去。Apple 只关心这个 URL 能打开、内容合理。

## 二、用户协议（可选但建议有）

```
# 用户协议

## 1. 服务描述
Aidear 是一款 AI 写作辅助工具，帮助用户将零散的想法扩展成结构化的文章。

## 2. 内容所有权
你拥有你输入的内容和生成的文章的所有权利。
AI 生成的内容可能存在相似性，我们不保证生成内容的独创性。

## 3. 使用限制
你不得使用本 App 生成违法、色情、暴力、骚扰或其他不当内容。
我们保留拒绝服务给违反使用条款用户的权利。

## 4. 免责声明
本 App 按"现状"提供。AI 生成的内容可能包含事实错误或不当表述，
用户应自行审阅和编辑生成的内容后再发布。

## 5. 服务可用性
我们不保证服务不中断。AI 服务可能因第三方原因不可用。

## 6. 联系我们
[YOUR_EMAIL]
```

## 三、App Store 隐私标签

提交 App 时，需要在 App Store Connect 填写隐私营养标签。

按照当前架构，你需要在以下项目打勾：

| 数据类型 | 用于追踪？ | 关联到你？ | 用途 |
|---|---|---|---|
| **用户内容**（输入文本） | 否 | 否 | App 功能 |
| **用户 ID**（匿名） | 否 | 否 | App 功能、防欺诈 |
| **使用数据** | 否 | 否 | 分析 |

> 如果后续加了 Crashlytics 或 Firebase Analytics，需要相应更新。

## 四、AI 生成内容合规

### App Store 审核

Apple 目前对 AI 生成内容的 App 没有特殊限制，但要求：
- 不能生成色情内容（应用内内容过滤）
- 不能生成虚假新闻或冒充他人的内容
- 如果能生成代码，不能执行恶意代码

### 内容过滤

建议在后端 Worker 中添加 OpenAI Moderation API 调用：

```javascript
// 在转发请求前检查用户输入
async function moderateContent(input, env) {
  const res = await fetch('https://api.openai.com/v1/moderations', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
    },
    body: JSON.stringify({ input }),
  });
  const data = await res.json();
  return data.results?.[0]?.flagged ?? false;
}

// 在主 handler 中
const body = await request.json();
const userInput = body.messages?.find(m => m.role === 'user')?.content || '';
const flagged = await moderateContent(userInput, env);
if (flagged) {
  return new Response(
    JSON.stringify({ error: '内容不符合使用规范' }),
    { status: 400, headers: { 'Content-Type': 'application/json' } }
  );
}
```

### App 内提示

在输入框上方可以加一行说明：

```
AI 生成的内容可能不准确，发布前请自行审阅
```

## 五、中国大陆特殊要求（如果是中国区上架）

### ICP 备案

如果你的后端服务器在中国大陆：
- 域名需要 ICP 备案（阿里云/腾讯云可以代办，20 天左右）
- 如果用 Cloudflare Workers（服务器在境外），用户通过 App 直连，不需要备案

### App 备案（工信部要求，2024 年起）

中国大陆区上架的 App 需要在工信部备案，流程：
1. App Store Connect 创建好 App 记录
2. 通过阿里云/腾讯云的"App 备案"服务提交
3. 等待 20 个工作日审核
4. 获得备案号后填入 App Store Connect

> 建议先上架中国区以外的市场，后续再处理备案。因为备案需要 App 已有明确的功能和界面截图。

## 检查清单

- [ ] 隐私政策文案完成并发布到线上 URL
- [ ] 用户协议完成并发布到线上 URL（可选）
- [ ] App Store Connect 隐私标签填写完成
- [ ] 后端 Worker 添加 Moderation API 内容过滤
- [ ] App 内添加"AI 内容可能不准确"提示
- [ ] 确认不收集不必要的用户数据
- [ ] （中国区）确认是否需要 App 备案
