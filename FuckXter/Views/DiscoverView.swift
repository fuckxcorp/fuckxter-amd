import SwiftUI

struct DiscoverView: View {
    @State private var query = ""
    @State private var result: SearchResult?
    @State private var isSearching = false
    @State private var error: String?
    var body: some View {
        List {
            if let result {
                if !result.users.isEmpty {
                    Section("用户") {
                        ForEach(result.users) { user in
                            NavigationLink(value: UserDestination(handle: user.handle)) {
                                HStack {
                                    AvatarView(user: FeedUser(id: user.id, name: user.name, handle: user.handle, verified: user.verified, avatarUrl: user.avatarUrl))
                                    VStack(alignment: .leading) { Text(user.name).fontWeight(.semibold); Text("@\(user.handle) · \(user.stats.followers) 粉丝").font(.caption).foregroundStyle(.secondary) }
                                }
                            }
                        }
                    }
                }
                if !result.posts.isEmpty { Section("帖子") { ForEach(result.posts) { PostRow(post: $0) } } }
                if result.users.isEmpty && result.posts.isEmpty { ContentUnavailableView("没有结果", systemImage: "magnifyingglass", description: Text("换一个关键词试试。")) }
            } else { ContentUnavailableView("发现新的声音", systemImage: "sparkles", description: Text("搜索用户、话题或帖子内容。")) }
        }
        .navigationTitle("发现").searchable(text: $query, prompt: "搜索用户或帖子").onSubmit(of: .search) { Task { await search() } }.navigationDestination(for: UserDestination.self) { UserProfileView(handle: $0.handle) }.navigationDestination(for: PostDestination.self) { PostDetailView(post: $0.post) }.overlay { if isSearching { ProgressView() } }.alert("搜索失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("好", role: .cancel) {} } message: { Text(error ?? "") }
    }
    private func search() async { guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }; isSearching = true; defer { isSearching = false }; do { result = try await APIClient.shared.search(query) } catch { self.error = error.localizedDescription } }
}
