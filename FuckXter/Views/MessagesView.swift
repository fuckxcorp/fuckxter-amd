import SwiftUI

struct MessagesView: View {
    @EnvironmentObject private var api: APIClient
    @State private var threads: [Conversation] = []
    @State private var error: String?
    var body: some View {
        Group {
            if api.account == nil { ContentUnavailableView("登录后查看私信", systemImage: "bubble.left.and.bubble.right", description: Text("和你关注的人开始一段对话。")) }
            else { List { ForEach(threads) { thread in NavigationLink(value: ConversationDestination(handle: thread.other.handle, user: thread.other)) { HStack(spacing: 12) { AvatarView(user: thread.other); VStack(alignment: .leading, spacing: 3) { HStack { Text(thread.other.name).fontWeight(.semibold); Spacer(); Text(relativeTime(thread.lastMessageAt)).font(.caption).foregroundStyle(.secondary) }; Text(thread.lastMessage?.body ?? "开始聊天").foregroundStyle(.secondary).lineLimit(1) }; if thread.unread > 0 { Text("\(thread.unread)").font(.caption2).fontWeight(.bold).foregroundStyle(.white).padding(6).background(.blue, in: Circle()) } } } }; if threads.isEmpty { ContentUnavailableView("还没有私信", systemImage: "tray", description: Text("从用户主页点击私信来开始聊天。")) } }.listStyle(.plain).refreshable { await load() }.task { await load() }.navigationDestination(for: ConversationDestination.self) { ConversationView(destination: $0) } }
        }.navigationTitle("私信").alert("加载失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("好", role: .cancel) {} } message: { Text(error ?? "") }
    }
    private func load() async { do { threads = try await api.conversations().threads } catch { self.error = error.localizedDescription } }
}

struct ConversationDestination: Hashable { let handle: String; let user: FeedUser }
struct ConversationView: View {
    @EnvironmentObject private var api: APIClient
    let destination: ConversationDestination
    @State private var page: ConversationPage?
    @State private var text = ""
    @State private var error: String?
    var body: some View {
        VStack(spacing: 0) {
            if let page { ScrollViewReader { proxy in ScrollView { LazyVStack(spacing: 10) { ForEach(page.messages) { message in HStack { if message.mine { Spacer() }; Text(message.body).padding(.horizontal, 13).padding(.vertical, 9).foregroundStyle(message.mine ? .white : .primary).background(message.mine ? Color.accentColor : Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 16)); if !message.mine { Spacer() } }.id(message.id) } }.padding() }.onAppear { proxy.scrollTo(page.messages.last?.id, anchor: .bottom) } } } else { Spacer(); ProgressView(); Spacer() }
            Divider(); HStack(alignment: .bottom) { TextField("写点私信…", text: $text, axis: .vertical).lineLimit(1...5).textFieldStyle(.roundedBorder); Button { Task { await send() } } label: { Image(systemName: "arrow.up.circle.fill").font(.title2) }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || page?.canSend == false) }.padding()
        }.navigationTitle(destination.user.name).navigationBarTitleDisplayMode(.inline).task { await load() }.alert("发送失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("好", role: .cancel) {} } message: { Text(error ?? "") }
    }
    private func load() async { do { page = try await api.conversation(destination.handle) } catch { self.error = error.localizedDescription } }
    private func send() async { do { page = try await api.sendMessage(destination.handle, text: text); text = "" } catch { self.error = error.localizedDescription } }
}
