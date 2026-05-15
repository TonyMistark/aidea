# 后端代理服务方案

## 问题

当前架构：

```
App (客户端) → 请求里带 API Key → OpenAI API
```

问题：
1. **API Key 泄露** — 逆向 App 即可提取 Key，被盗刷账单
2. **App Store 拒审** — Apple 不允许在客户端代码中硬编码第三方服务的 API Key
3. **无权限控制** — 任何人都能用你的 Key 无限调用，无法限流，无法封禁滥用

## 目标架构

```
App (客户端) → Bearer Token → 后端代理 → API Key → OpenAI API
                                  ↑
                          Sign in with Apple
                           验证用户身份
```

## 方案选择

### 方案 A：Cloudflare Workers（推荐）

**最适合这个项目**，原因：
- 免费额度很慷慨：每天 10 万次请求
- 全球边缘节点，延迟低（中国用户走香港/新加坡节点）
- 零运维，代码部署即上线
- Workers AI 未来可以直接用 Cloudflare 的 AI 网关

```
成本：$0/月（免费额度内）
```

### 方案 B：Vercel Serverless Functions

适合 Next.js 项目，但你是 iOS 原生 App，不需要。

### 方案 C：自建 VPS（阿里云/腾讯云）

控制力最强，但需要运维，国内服务器需要备案。

## 方案 A 实施步骤

### 1. 注册 Cloudflare

- 打开 [cloudflare.com](https://cloudflare.com)
- 注册账号
- 不需要购买域名（可以用 workers.dev 子域名）

### 2. 安装 Wrangler CLI

```bash
npm install -g wrangler
wrangler login
```

### 3. 创建 Worker 项目

```bash
mkdir aidear-api && cd aidear-api
wrangler init aidear-api
```

### 4. 编写 Worker 代码

`src/index.js`：

```javascript
export default {
  async fetch(request, env) {
    // CORS 预检
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          'Access-Control-Max-Age': '86400',
        }
      });
    }

    // 只允许 POST
    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    // 验证用户 Bearer Token（后续集成 Sign in with Apple）
    const authHeader = request.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response('Unauthorized', { status: 401 });
    }
    // TODO: 验证 token 有效性

    // 构造 OpenAI 请求
    const body = await request.json();
    const openaiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
      },
      body: JSON.stringify(body),
    });

    // 透传响应
    const responseData = await openaiResponse.text();
    return new Response(responseData, {
      status: openaiResponse.status,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    });
  },
};
```

### 5. 配置环境变量

```bash
# 将 OpenAI API Key 设为 Worker 的 secret
wrangler secret put OPENAI_API_KEY
# 粘贴你的 sk-xxx...

# wrangler.toml
```

`wrangler.toml`：

```toml
name = "aidear-api"
main = "src/index.js"
compatibility_date = "2025-01-01"

[vars]
ALLOWED_ORIGINS = "*"
```

### 6. 部署

```bash
wrangler deploy
```

部署后会得到一个 URL：`https://aidear-api.<your-subdomain>.workers.dev`

### 7. App 端改动

`GenerationService.swift` 中的改动很小，只需 3 处：

```swift
// 改前：
let url = URL(string: "\(settings.apiBaseURL)/chat/completions")!
request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")

// 改后：
let url = URL(string: "https://aidear-api.xxx.workers.dev/chat/completions")!
// 不再需要 API Key header，改用用户 token
request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
```

用户 token 由 Sign in with Apple 流程获取（详见 sign-in-with-apple.md）。

## 进阶功能

### 限流

```javascript
// 在 Worker 中添加基于 IP 或用户的限流
// Cloudflare 有内置的 Rate Limiting，也可以在代码里实现简单版
const RATE_LIMIT_MAP = new Map();

function checkRateLimit(userId) {
  const now = Date.now();
  const windowMs = 60 * 1000; // 1 分钟窗口
  const maxRequests = 20;      // 每分钟最多 20 次
  
  const record = RATE_LIMIT_MAP.get(userId) || { count: 0, resetAt: now + windowMs };
  if (now > record.resetAt) {
    record.count = 0;
    record.resetAt = now + windowMs;
  }
  record.count++;
  RATE_LIMIT_MAP.set(userId, record);
  return record.count <= maxRequests;
}
```

### 内容过滤

```javascript
// 可以调用 OpenAI Moderation API 做内容审核
async function moderateContent(text, env) {
  const res = await fetch('https://api.openai.com/v1/moderations', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
    },
    body: JSON.stringify({ input: text }),
  });
  const data = await res.json();
  return data.results?.[0]?.flagged ?? false;
}
```

### 使用 Cloudflare AI Gateway（免费）

Cloudflare 提供专门的 AI 网关，可以缓存请求、记录日志、分析用量：

```bash
# 在 Cloudflare Dashboard 创建一个 AI Gateway
# 然后修改 Worker 中的 URL 即可
https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_id}/openai/chat/completions
```

## 部署后检查清单

- [ ] `wrangler deploy` 成功后，curl 测试 endpoint 正常
- [ ] 不带 Authorization header 请求返回 401
- [ ] 带正确 header 的请求能正常返回 AI 生成结果
- [ ] 在 Cloudflare Dashboard 看到请求日志
- [ ] App 端改为新 URL 后功能正常
