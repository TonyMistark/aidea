# App Store 上架总清单

## 一、架构与安全 🔴 必须先做

- [ ] **后端代理服务** — 将 API Key 从客户端移到服务端 → 详见 [backend-proxy.md](./backend-proxy.md)
- [ ] **用户认证** — Sign in with Apple + 后端验证 → 详见 [sign-in-with-apple.md](./sign-in-with-apple.md)
- [ ] App 端网络层改造 — 直连 OpenAI 改为调自家后端

## 二、法律与合规 🔴 审核前提

- [ ] **隐私政策** — 线上可访问的 URL → 详见 [privacy-and-compliance.md](./privacy-and-compliance.md)
- [ ] **用户协议** — 可选但建议有
- [ ] AI 生成内容免责声明
- [ ] 数据收集说明（用户输入内容传给 AI 服务）

## 三、App Store Connect 操作

- [ ] 创建 App 记录（App Store Connect → 我的 App → +）
- [ ] 填写 Bundle ID：`com.aidear.app`
- [ ] 填写隐私政策 URL
- [ ] 完成年龄分级问卷
- [ ] 配置 App 价格（免费）
- [ ] 选择发布地区（至少中国大陆 + 全球主要市场）

## 四、元数据与素材

- [ ] App 图标 1024×1024 → 详见 [app-store-materials.md](./app-store-materials.md)
- [ ] 6.7" 截图（iPhone 17 Pro Max）：至少 3 张
- [ ] 6.1" 截图（iPhone 17e / Air）：至少 3 张
- [ ] App 描述文案（中英文）
- [ ] 关键词（100 字符以内）
- [ ] 宣传文本（170 字符以内）
- [ ] 技术支持 URL

## 五、代码质量

- [ ] Mock 数据完善 — 确保审核员未登录也能完整体验
- [ ] 错误处理 — 网络超时、API 异常的用户友好提示
- [ ] 无崩溃 — Xcode Organizer 查看 Crash Log
- [ ] 移除调试代码、print 语句
- [ ] 确认 ATS（App Transport Security）配置正确
- [ ] 检查是否有私有 API 调用

## 六、测试与提交

- [ ] TestFlight 内部测试（至少邀请 2-3 人试用）
- [ ] 真机测试（非模拟器）
- [ ] Archive → Validate App 通过
- [ ] 上传至 App Store Connect
- [ ] 填写审核备注（说明 AI 功能如何工作、测试账号等）
- [ ] 提交审核

---

## 推荐推进顺序

```
第一步：搭建后端代理 ──┐
                       ├──> 这些做完才能安全发布
第二步：Sign in with Apple ─┘

第三步：隐私政策 + 用户协议（写个页面发布到 GitHub Pages）

第四步：App Store Connect 创建 App + 准备素材（可并行）

第五步：App 端改造（更新网络层、优化错误处理）

第六步：TestFlight 测试 → 提交审核
```
