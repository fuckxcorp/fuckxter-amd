import SwiftUI
import PhotosUI

struct FeedView: View {
    let usesCanvasData: Bool
    @State private var tab: TimelineTab = .foryou
    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var error: String?
    var body: some View {
        List {
            Section { Picker("时间线", selection: $tab) { ForEach(TimelineTab.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented).listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 8, trailing: 16)) }
            if isLoading && posts.isEmpty { Section { HStack { Spacer(); ProgressView(); Spacer() } } }
            ForEach(posts) { post in PostRow(post: post).listRowSeparator(.visible) }
            if !isLoading && posts.isEmpty { ContentUnavailableView("暂无帖子", systemImage: "rectangle.stack", description: Text("稍后再来看看。")) }
        }
        .listStyle(.plain).navigationTitle("FuckXter")
        .toolbar { ToolbarItem(placement: .topBarLeading) { BrandLogo(side: 28) } }
        .navigationDestination(for: PostDestination.self) { PostDetailView(post: $0.post) }
        .navigationDestination(for: UserDestination.self) { UserProfileView(handle: $0.handle) }
        .refreshable { await load() }.task(id: tab) { await load() }
        .alert("加载失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("重试") { Task { await load() } }; Button("取消", role: .cancel) {} } message: { Text(error ?? "") }
    }
    private func load() async {
        if usesCanvasData {
            posts = [.canvasExample]
            return
        }
        isLoading = true; defer { isLoading = false }
        do { posts = try await APIClient.shared.timeline(tab).posts } catch { self.error = error.localizedDescription }
    }
}

private extension Post {
    static let canvasExample = Post(
        id: "canvas-post", slug: "welcome", author: FeedUser(id: "canvas-user", name: "FuckXter", handle: "fuckxter", verified: true, avatarUrl: nil), text: "欢迎来到 FuckXter。这里是原生 iPhone 预览中的示例帖子。", createdAt: ISO8601DateFormatter().string(from: Date()), visibility: "public", stats: PostStats(replies: 2, reposts: 3, likes: 12, views: 86), media: nil, viewer: PostViewer(liked: false, reposted: false, saved: false, followingAuthor: false, isAuthor: false)
    )
}

struct ComposerView: View {
    @EnvironmentObject private var api: APIClient
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var visibility = "public"
    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var isPosting = false
    @State private var error: String?
    let onComplete: () -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section { TextEditor(text: $text).frame(minHeight: 170).overlay(alignment: .bottomTrailing) { Text("\(text.count) / 1000").font(.caption).foregroundStyle(text.count > 1000 ? .red : .secondary).padding(8) } }
                Section("可见范围") { Picker("谁能看到", selection: $visibility) { Text("公开可见").tag("public"); Text("仅互关可见").tag("mutual"); Text("私密贴").tag("private") }.pickerStyle(.menu) }
                Section("附件") { PhotosPicker(selection: $pickerItem, matching: .images) { Label("选择图片", systemImage: "photo") }; if let image { Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 12)); Button("移除图片", role: .destructive) { self.image = nil; pickerItem = nil } } }
            }.navigationTitle("新帖子").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button(isPosting ? "发布中" : "发布") { Task { await publish() } }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 1000 || isPosting) } }
        }.onChange(of: pickerItem) { _, newItem in Task { @MainActor in guard let data = try? await newItem?.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) else { return }; image = uiImage } }.alert("无法发布", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("好", role: .cancel) {} } message: { Text(error ?? "") }
    }
    private func publish() async { guard api.account != nil else { error = "请先登录。"; return }; isPosting = true; defer { isPosting = false }; do { let media: PostMedia?; if let image { media = try await api.uploadMedia(image) } else { media = nil }; _ = try await api.createPost(text: text.trimmingCharacters(in: .whitespacesAndNewlines), mediaId: media?.id, visibility: visibility); onComplete(); dismiss() } catch { self.error = error.localizedDescription } }
}

struct PostDetailView: View {
    @EnvironmentObject private var api: APIClient
    let post: Post
    @State private var comments: [Comment] = []
    @State private var reply = ""
    @State private var error: String?
    var body: some View {
        List {
            Section { PostRow(post: post).disabled(true) }
            Section("回帖 · \(comments.count)") { if comments.isEmpty { Text("还没有回帖，来抢沙发吧。").foregroundStyle(.secondary) }; ForEach(comments) { comment in CommentRow(comment: comment) } }
            if api.account != nil { Section { HStack { TextField("写一条回帖…", text: $reply, axis: .vertical).lineLimit(1...5); Button("发送") { Task { await send() } }.disabled(reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } } }
        }.listStyle(.plain).navigationTitle("帖子").navigationBarTitleDisplayMode(.inline).task { await load() }.alert("操作失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("好", role: .cancel) {} } message: { Text(error ?? "") }
    }
    private func load() async { do { comments = try await api.comments(postID: post.id).comments } catch { self.error = error.localizedDescription } }
    private func send() async { do { let new = try await api.comment(postID: post.id, text: reply); comments.append(new); reply = "" } catch { self.error = error.localizedDescription } }
}

private struct CommentRow: View {
    let comment: Comment
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(user: comment.author, size: 34)
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text(comment.author.name).fontWeight(.semibold); Text("@\(comment.author.handle)").foregroundStyle(.secondary); Text("· \(relativeTime(comment.createdAt))").foregroundStyle(.secondary) }.font(.caption)
                Text(comment.text)
                HStack(spacing: 15) { Label("\(comment.stats.likes)", systemImage: comment.viewer.liked ? "heart.fill" : "heart"); Label("\(comment.stats.reposts)", systemImage: "arrow.2.squarepath") }.font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
