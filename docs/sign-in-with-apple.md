# Sign in with Apple 接入方案

## 为什么需要

1. **App Store 审核要求** — 如果你的 App 有账号系统，必须提供 Sign in with Apple（App Store Review Guideline 4.8）
2. **保护后端 API** — 用户身份 token 传给后端验证，防止未授权调用
3. **用户体验** — 一键登录，不需要密码，不需要邮箱验证

## 三种接入级别

### 级别 1：仅客户端验证（最简单，本次推荐）

```
用户点"登录" → Apple 弹窗 → Face ID / Touch ID → 获得 user ID
                                                     ↓
                                                传给后端做身份标识
```

- 无需后端改动（Apple 的 token 验证在客户端完成）
- user ID 是稳定的匿名标识符，用于限流和防滥用
- 半小时内可实现

### 级别 2：服务端验证 token（更安全）

```
客户端获取 Apple identityToken → 传给后端 → 后端向 Apple 验证 token 合法性
```

- 需要后端多一步 Apple ID token 验证
- 防止伪造请求

### 级别 3：完整账号系统

- 关联邮箱、iCloud、跨设备同步历史记录等
- 目前不需要，远超 MVP 需求

## 级别 1 实施步骤

### 1. Xcode 配置

在 Xcode 中打开项目 → Target `aidear` → Signing & Capabilities → + Capability → 搜 `Sign in with Apple`

这会在 entitlements 文件中添加 `com.apple.developer.applesignin`。

### 2. Swift 实现

创建 `AuthenticationService.swift`：

```swift
import AuthenticationServices
import CryptoKit

final class AuthenticationService: NSObject, ObservableObject {
    @Published var userID: String?
    @Published var isSignedIn = false

    private var currentNonce: String?
    private let userIDKey = "apple_user_id"

    override init() {
        super.init()
        userID = UserDefaults.standard.string(forKey: userIDKey)
        isSignedIn = userID != nil
    }

    // MARK: - Public

    func handleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [] // 不索取姓名和邮箱，只要匿名 ID
        request.nonce = sha256(nonce)
    }

    func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                userID = credential.user
                UserDefaults.standard.set(credential.user, forKey: userIDKey)
                isSignedIn = true
            }
        case .failure(let error):
            print("Sign in with Apple failed: \(error)")
        }
    }

    // 检查凭证是否仍然有效（App 启动时调用）
    func checkCredentialState() {
        guard let userID else { return }
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: userID) { state, error in
            DispatchQueue.main.async {
                self.isSignedIn = state == .authorized
            }
        }
    }

    func signOut() {
        userID = nil
        isSignedIn = false
        UserDefaults.standard.removeObject(forKey: userIDKey)
    }

    // MARK: - Helpers

    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            var random = UInt8()
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status == errSecSuccess && random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
```

### 3. SwiftUI 登录按钮

在 `SettingsView.swift` 或 `ContentView.swift` 中添加：

```swift
import AuthenticationServices

struct SignInWithAppleButton: View {
    @EnvironmentObject var authService: AuthenticationService

    var body: some View {
        if authService.isSignedIn {
            Button("退出登录") {
                authService.signOut()
            }
        } else {
            SignInWithAppleButtonView()
        }
    }
}

struct SignInWithAppleButtonView: UIViewRepresentable {
    @EnvironmentObject var authService: AuthenticationService

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton()
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.didTap),
            for: .touchUpInside
        )
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(authService: authService)
    }

    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let authService: AuthenticationService

        init(authService: AuthenticationService) {
            self.authService = authService
        }

        @objc func didTap() {
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            authService.handleSignInRequest(request)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }

        func authorizationController(controller: ASAuthorizationController,
                                     didCompleteWithAuthorization authorization: ASAuthorization) {
            authService.handleSignInResult(.success(authorization))
        }

        func authorizationController(controller: ASAuthorizationController,
                                     didCompleteWithError error: Error) {
            authService.handleSignInResult(.failure(error))
        }

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            // 获取当前的 key window
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first else {
                fatalError("No window found")
            }
            return window
        }
    }
}
```

### 4. 在 App 入口注入

`aidearApp.swift`：

```swift
@main
struct AidearApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var authService = AuthenticationService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(authService)
        }
    }
}
```

### 5. 与后端代理联动

`GenerationService.swift` 改造请求头：

```swift
// 改前
request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")

// 改后
guard let token = authService.userID else {
    throw AuthError.notSignedIn
}
request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
```

后端 Worker 收到 `userID` 后可以用来做限流计数。

## 级别 2 升级：服务端验证 token

如果后续需要更高安全性，在 `/generate` 请求中附带 `identityToken`：

```swift
// 客户端获取 identityToken（在 ASAuthorizationAppleIDCredential 回调中保存）
let token = String(data: credential.identityToken!, encoding: .utf8)!

// 请求时附在 header
request.setValue("Bearer \(token)", forHTTPHeaderField: "X-Apple-Identity-Token")
```

后端 Worker 向 Apple 验证：

```javascript
async function verifyAppleToken(token) {
  // 1. 获取 Apple 的公钥
  const keysRes = await fetch('https://appleid.apple.com/auth/keys');
  const { keys } = await keysRes.json();
  
  // 2. 用公钥验证 JWT（需要 jose 或类似库）
  // 3. 检查 issuer == "https://appleid.apple.com"
  // 4. 检查 aud == your bundle id
  // 5. 检查 exp 未过期
  return true; // 或 false
}
```

> Cloudflare Workers 可以使用 `@tsndr/cloudflare-worker-jwt` 库来做 JWT 验证。

## 检查清单

- [ ] Xcode 添加 Sign in with Apple capability
- [ ] `AuthenticationService.swift` 文件创建并编译通过
- [ ] 登录按钮在 Settings 页可见
- [ ] 点登录 → Face ID / Touch ID 验证 → 登录成功
- [ ] 退出登录功能正常
- [ ] userID 持久化（关掉 App 重开仍是登录态）
- [ ] App 启动时检查凭证状态
- [ ] `GenerationService` 改用 userID 作为 Authorization header
- [ ] 后端 Worker 能收到 userID 并做基本校验
