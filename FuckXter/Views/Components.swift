import SwiftUI

/// 原样使用 public/FuckXter.icon/Assets 中的项目 Logo，不重绘品牌标识。
struct BrandLogo: View {
    var side: CGFloat = 48
    var body: some View {
        if let image = Self.image {
            Image(uiImage: image).resizable().scaledToFit().frame(width: side, height: side).accessibilityLabel("FuckXter")
        }
    }
    private static let image: UIImage? = {
        guard let icon = Bundle.main.url(forResource: "FuckXter", withExtension: "icon") else { return nil }
        return UIImage(contentsOfFile: icon.appendingPathComponent("Assets/fuckxter_logo.png").path)
    }()
}

struct AvatarView: View {
    let user: FeedUser
    var size: CGFloat = 44
    var body: some View {
        AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in image.resizable().scaledToFill() } placeholder: { Text(user.name.prefix(1).uppercased()).font(.system(size: size * 0.42, weight: .bold)).foregroundStyle(.white).frame(width: size, height: size).background(gradient) }
            .frame(width: size, height: size).clipShape(Circle()).accessibilityLabel(user.name)
    }
    private var gradient: LinearGradient { let hue = Double(abs(user.handle.hashValue % 360)) / 360; return LinearGradient(colors: [Color(hue: hue, saturation: 0.60, brightness: 0.76), Color(hue: hue, saturation: 0.82, brightness: 0.45)], startPoint: .topLeading, endPoint: .bottomTrailing) }
}

struct PostRow: View {
    @EnvironmentObject private var api: APIClient
    @State private var post: Post
    @State private var actionError: String?
    init(post: Post) { _post = State(initialValue: post) }
    var body: some View {
        NavigationLink(value: PostDestination(post: post)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    NavigationLink(value: UserDestination(handle: post.author.handle)) { AvatarView(user: post.author) }.buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) { Text(post.author.name).fontWeight(.semibold).lineLimit(1); if post.author.verified == true { Image(systemName: "checkmark.seal.fill").foregroundStyle(.blue).font(.caption) }; Text("@\(post.author.handle)").foregroundStyle(.secondary); Text("· \(relativeTime(post.createdAt))").foregroundStyle(.secondary) }.font(.subheadline)
                        Text(post.text).multilineTextAlignment(.leading).foregroundStyle(.primary)
                    }
                }
                if let media = post.media, let url = URL(string: media.url) { AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { ProgressView().frame(maxWidth: .infinity, minHeight: 180) }.frame(maxWidth: .infinity, minHeight: 180, maxHeight: 340).clipShape(RoundedRectangle(cornerRadius: 16)) }
                HStack { interaction("bubble.left", post.stats.replies) {}; Spacer(); interaction("arrow.2.squarepath", post.stats.reposts, active: post.viewer?.reposted == true) { await mutateRepost() }; Spacer(); interaction("heart", post.stats.likes, active: post.viewer?.liked == true) { await mutateLike() }; Spacer(); interaction("bookmark", nil, active: post.viewer?.saved == true) { await mutateSave() }; Spacer(); Label("\(post.stats.views)", systemImage: "chart.bar") .font(.caption).foregroundStyle(.secondary) }
                    .padding(.leading, 54)
            }.padding(.vertical, 10)
        }.buttonStyle(.plain).alert("操作失败", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) { Button("好", role: .cancel) {} } message: { Text(actionError ?? "") }
    }
    private func interaction(_ icon: String, _ count: Int?, active: Bool = false, action: @escaping () async -> Void) -> some View { Button { Task { await action() } } label: { HStack(spacing: 4) { Image(systemName: active ? "\(icon).fill" : icon); if let count { Text(compactCount(count)) } }.font(.caption).foregroundStyle(active ? Color.accentColor : Color.secondary) }.buttonStyle(.plain) }
    private func mutateLike() async { guard api.account != nil else { actionError = "请先登录后点赞。"; return }; do { let r = try await api.like(post, enabled: post.viewer?.liked != true); post.viewer = PostViewer(liked: r.liked, reposted: post.viewer?.reposted ?? false, saved: post.viewer?.saved ?? false, followingAuthor: post.viewer?.followingAuthor, isAuthor: post.viewer?.isAuthor); post.stats = PostStats(replies: post.stats.replies, reposts: post.stats.reposts, likes: r.likes, views: post.stats.views) } catch { actionError = error.localizedDescription } }
    private func mutateRepost() async { guard api.account != nil else { actionError = "请先登录后转发。"; return }; do { let r = try await api.repost(post, enabled: post.viewer?.reposted != true); post.viewer = PostViewer(liked: post.viewer?.liked ?? false, reposted: r.reposted, saved: post.viewer?.saved ?? false, followingAuthor: post.viewer?.followingAuthor, isAuthor: post.viewer?.isAuthor); post.stats = PostStats(replies: post.stats.replies, reposts: r.reposts, likes: post.stats.likes, views: post.stats.views) } catch { actionError = error.localizedDescription } }
    private func mutateSave() async { guard api.account != nil else { actionError = "请先登录后收藏。"; return }; do { _ = try await api.save(post, enabled: post.viewer?.saved != true); post.viewer = PostViewer(liked: post.viewer?.liked ?? false, reposted: post.viewer?.reposted ?? false, saved: post.viewer?.saved != true, followingAuthor: post.viewer?.followingAuthor, isAuthor: post.viewer?.isAuthor) } catch { actionError = error.localizedDescription } }
}

struct UserDestination: Hashable { let handle: String }
struct PostDestination: Hashable { let post: Post }
func relativeTime(_ date: String) -> String { guard let value = ISO8601DateFormatter().date(from: date) else { return "刚刚" }; let seconds = Int(Date().timeIntervalSince(value)); if seconds < 60 { return "刚刚" }; if seconds < 3600 { return "\(seconds / 60) 分" }; if seconds < 86400 { return "\(seconds / 3600) 小时" }; return "\(seconds / 86400) 天" }
func compactCount(_ value: Int) -> String { value >= 10_000 ? String(format: "%.1f万", Double(value) / 10_000) : "\(value)" }
