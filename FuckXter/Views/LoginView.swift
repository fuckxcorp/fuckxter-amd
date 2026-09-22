import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var api: APIClient
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""; @State private var password = ""; @State private var code = ""; @State private var recoveryCode = ""; @State private var useRecoveryCode = false; @State private var needs2FA = false; @State private var isSubmitting = false; @State private var error: String?
    let onComplete: () -> Void
    var body: some View {
        NavigationStack { VStack(spacing: 22) { Spacer(); BrandLogo(side: 78); Text("FuckXter").font(.largeTitle).fontWeight(.bold); Text("登录或注册，参与无算法的公共讨论。") .multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal, 32); VStack(spacing: 12) { TextField("邮箱", text: $email).textContentType(.username).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder); SecureField("密码", text: $password).textContentType(.password).textFieldStyle(.roundedBorder); if needs2FA { TextField(useRecoveryCode ? "恢复码 XXXX-XXXX" : "6 位动态验证码", text: useRecoveryCode ? $recoveryCode : $code).keyboardType(.numberPad).textFieldStyle(.roundedBorder); Button(useRecoveryCode ? "使用动态验证码" : "使用恢复码") { useRecoveryCode.toggle() }.font(.footnote) }; Button(isSubmitting ? "正在登录…" : "登录 / 注册") { Task { await submit() } }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity).disabled(email.isEmpty || password.isEmpty || isSubmitting) }.padding(.horizontal, 24); Text("未注册的邮箱会自动创建账号。") .font(.footnote).foregroundStyle(.secondary); Spacer() }.navigationTitle("欢迎").toolbar { Button("关闭") { dismiss() } }.alert("无法登录", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("好", role: .cancel) {} } message: { Text(error ?? "") } }
    }
    private func submit() async { isSubmitting = true; defer { isSubmitting = false }; do { _ = try await api.signIn(identifier: email, password: password, code: needs2FA && !useRecoveryCode ? code : nil, recoveryCode: needs2FA && useRecoveryCode ? recoveryCode : nil); onComplete(); dismiss() } catch { let description = error.localizedDescription; if description.contains("验证") || description.lowercased().contains("2fa") { needs2FA = true }; self.error = description } }
}
