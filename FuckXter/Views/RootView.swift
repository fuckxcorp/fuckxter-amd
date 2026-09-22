import SwiftUI

struct RootView: View {
    @EnvironmentObject private var api: APIClient
    let usesCanvasData: Bool
    @State private var selectedTab = 0
    @State private var showComposer = false
    @State private var showLogin = false

    var body: some View {
        Group {
            if !usesCanvasData && api.isLoadingSession {
                ProgressView("正在连接 FuckXter…")
            } else {
                TabView(selection: $selectedTab) {
                    NavigationStack { FeedView(usesCanvasData: usesCanvasData) }
                        .tabItem { Label("首页", systemImage: "house") }.tag(0)
                    NavigationStack { DiscoverView() }
                        .tabItem { Label("发现", systemImage: "magnifyingglass") }.tag(1)
                    NavigationStack { ActivityView() }
                        .tabItem { Label("动态", systemImage: "bell") }.tag(2)
                    NavigationStack { MessagesView() }
                        .tabItem { Label("私信", systemImage: "bubble.left.and.bubble.right") }.tag(3)
                    NavigationStack { ProfileEntryView(showLogin: $showLogin) }
                        .tabItem { Label("我的", systemImage: "person") }.tag(4)
                }
                .tint(.accentColor)
                .safeAreaInset(edge: .bottom) {
                    if selectedTab == 0 { Button { showComposer = true } label: { Label("发帖", systemImage: "square.and.pencil").fontWeight(.semibold).frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).padding(.horizontal, 22).padding(.top, 8).accessibilityHint("发布新的帖子") }
                }
            }
        }
        .sheet(isPresented: $showComposer) { ComposerView { showComposer = false } }
        .sheet(isPresented: $showLogin) { LoginView { showLogin = false } }
    }
}

private struct ProfileEntryView: View {
    @EnvironmentObject private var api: APIClient
    @Binding var showLogin: Bool
    var body: some View {
        Group {
            if let account = api.account { UserProfileView(handle: account.profile.handle, isCurrentUser: true) }
            else { ContentUnavailableView("登录以管理你的空间", systemImage: "person.crop.circle.badge.plus", description: Text("发帖、关注、收藏和私信需要登录。")); Button("登录 / 注册") { showLogin = true }.buttonStyle(.borderedProminent) }
        }
    }
}

#Preview("主界面") {
    CanvasHomePreview()
}

/// Canvas 只展示布局，不初始化 URLSession、登录状态或真实 API。
private struct CanvasHomePreview: View {
    var body: some View {
        TabView {
            NavigationStack {
                List {
                    Picker("时间线", selection: .constant("推荐")) {
                        Text("推荐").tag("推荐")
                        Text("实时").tag("实时")
                        Text("关注").tag("关注")
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "at.circle.fill")
                                .font(.system(size: 42))
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading) {
                                Text("FuckXter").fontWeight(.semibold)
                                Text("@fuckxter · 刚刚").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Text("欢迎来到 FuckXter。这里是原生 iPhone 界面的实时 Canvas 预览。")
                        HStack(spacing: 28) {
                            Label("2", systemImage: "bubble.left")
                            Label("3", systemImage: "arrow.2.squarepath")
                            Label("12", systemImage: "heart")
                            Label("86", systemImage: "chart.bar")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .navigationTitle("FuckXter")
            }
            .tabItem { Label("首页", systemImage: "house") }
            Text("发现").tabItem { Label("发现", systemImage: "magnifyingglass") }
            Text("动态").tabItem { Label("动态", systemImage: "bell") }
            Text("私信").tabItem { Label("私信", systemImage: "bubble.left.and.bubble.right") }
            Text("我的").tabItem { Label("我的", systemImage: "person") }
        }
    }
}
