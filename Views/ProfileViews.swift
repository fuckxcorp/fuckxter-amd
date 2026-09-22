import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject private var api: APIClient
    let handle: String
    var isCurrentUser = false
    @State private var profile: UserProfile?
    @State private var posts: [Post] = []
    @State private var error: String?
    @State private var showSettings = false
    var body: some View {
        List {
            if let profile {
                Section { VStack(alignment: .leading, spacing: 12) { if let url = URL(string: profile.headerUrl ?? "") { AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { Rectangle().fill(.secondary.opacity(0.15)) }.frame(height: 120).clipShape(RoundedRectangle(cornerRadius: 16)) }; HStack(alignment: .bottom) { AvatarView(user: FeedUser(id: profile.id, name: profile.name, handle: profile.handle, verified: profile.verified, avatarUrl: profile.avatarUrl), size: 68); Spacer(); if isCurrentUser { Button("编辑资料") { showSettings = true }.buttonStyle(.bordered) } else { Button(profile.viewer.following ? "已关注" : "关注") { Task { await follow() } }.buttonStyle(.borderedProminent); Menu { Button(profile.viewer.blocked == true ? "取消拉黑" : "拉黑", role: profile.viewer.blocked == true ? nil : .destructive) { Task { await block() } } } label: { Image(systemName: "ellipsis") }.buttonStyle(.bordered) } }; Text(profile.name).font(.title2).fontWeight(.bold); Text("@\(profile.handle)").foregroundStyle(.secondary); if !profile.bio.isEmpty { Text(profile.bio) }; HStack(spacing: 16) { Label("\(profile.stats.posts)", systemImage: "text.bubble"); Label("\(profile.stats.followers)", systemImage: "person.2"); Label("\(profile.stats.following)", systemImage: "person.2.fill") }.font(.subheadline).foregroundStyle(.secondary); if !profile.region.isEmpty || !profile.gender.isEmpty { Text([profile.region, profile.gender].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) } }.padding(.vertical, 6) }
                Section("帖子") { if posts.isEmpty { Text("还没有帖子").foregroundStyle(.secondary) }; ForEach(posts) { PostRow(post: $0) } }
            } else { Section { HStack { Spacer(); ProgressView(); Spacer() } } }
        }.listStyle(.plain).navigationTitle(isCurrentUser ? "我的主页" : "个人主页").navigationBarTitleDisplayMode(.inline).task(id: handle) { await load() }.navigationDestination(for: PostDestination.self) { PostDetailView(post: $0.post) }.navigationDestination(for: UserDestination.self) { UserProfileView(handle: $0.handle) }.sheet(isPresented: $showSettings) { SettingsView() }.alert("操作失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("好", role: .cancel) {} } message: { Text(error ?? "") }
    }
    private func load() async { do { async let p = api.profile(handle); async let stream = api.posts(handle: handle); profile = try await p; posts = try await stream } catch { self.error = error.localizedDescription } }
    private func follow() async { guard let profile else { return }; do { let result = try await api.setFollow(profile.handle, enabled: !profile.viewer.following); var changed = profile; changed.viewer = UserViewer(following: result.following, blocked: profile.viewer.blocked, canMessage: profile.viewer.canMessage); changed.stats = UserStats(posts: profile.stats.posts, followers: result.followers, following: profile.stats.following); self.profile = changed } catch { self.error = error.localizedDescription } }
    private func block() async { guard let profile else { return }; do { let result = try await api.setBlock(profile.handle, enabled: profile.viewer.blocked != true); var changed = profile; changed.viewer = UserViewer(following: profile.viewer.following, blocked: result.blocked, canMessage: profile.viewer.canMessage); self.profile = changed } catch { self.error = error.localizedDescription } }
}

struct SettingsView: View {
    @EnvironmentObject private var api: APIClient
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""; @State private var bio = ""; @State private var region = ""; @State private var gender = ""; @State private var birthday = ""; @State private var policy = "everyone"; @State private var currentPassword = ""; @State private var newPassword = ""; @State private var error: String?; @State private var confirmation = ""
    var body: some View {
        NavigationStack { Form { Section("个人资料") { TextField("昵称", text: $name); TextField("地区", text: $region); TextField("性别", text: $gender); TextField("生日（YYYY-MM-DD）", text: $birthday); TextField("个人简介", text: $bio, axis: .vertical).lineLimit(2...5); Button("保存资料") { Task { await saveProfile() } } }
            Section("私信权限") { Picker("谁可以私信我", selection: $policy) { Text("所有人").tag("everyone"); Text("仅互相关注").tag("mutual"); Text("不接收私信").tag("nobody") }.onChange(of: policy) { _, next in Task { await savePolicy(next) } } }
            Section("更改密码") { SecureField("当前密码", text: $currentPassword); SecureField("新密码（至少 8 位）", text: $newPassword); Button("更新密码") { Task { await changePassword() } }.disabled(currentPassword.isEmpty || newPassword.count < 8) }
            Section { Button("退出登录", role: .destructive) { Task { await api.signOut(); dismiss() } }; Button("删除账号", role: .destructive) { confirmation = "delete" } } footer: { Text("删除后会立即退出，三天内重新登录可取消删除。") } }.navigationTitle("设置").toolbar { Button("完成") { dismiss() } }.onAppear { seed() }.alert("删除账号？", isPresented: Binding(get: { confirmation == "delete" }, set: { if !$0 { confirmation = "" } })) { Button("删除", role: .destructive) { Task { await deleteAccount() } }; Button("取消", role: .cancel) {} } message: { Text("你的内容会隐藏；三天后会永久删除。") }.alert("操作失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("好", role: .cancel) {} } message: { Text(error ?? "") } }
    }
    private func seed() { guard let p = api.account?.profile else { return }; name = p.name; bio = p.bio; region = p.region; gender = p.gender; birthday = p.birthday; policy = api.account?.dmPolicy ?? "everyone" }
    private func saveProfile() async { guard let old = api.account?.profile else { return }; do { _ = try await api.updateProfile(AccountProfile(name: name, handle: old.handle, bio: bio, email: old.email, region: region, gender: gender, birthday: birthday)) } catch { self.error = error.localizedDescription } }
    private func savePolicy(_ value: String) async { do { try await api.updateDMPermission(value) } catch { self.error = error.localizedDescription } }
    private func changePassword() async { do { try await api.changePassword(current: currentPassword, next: newPassword); currentPassword = ""; newPassword = "" } catch { self.error = error.localizedDescription } }
    private func deleteAccount() async { do { try await api.deleteAccount(); dismiss() } catch { self.error = error.localizedDescription } }
}
