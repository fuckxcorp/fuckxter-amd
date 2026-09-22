import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var api: APIClient
    @State private var notices: [AppNotification] = []
    @State private var error: String?
    var body: some View {
        Group {
            if api.account == nil { ContentUnavailableView("登录后查看动态", systemImage: "bell.slash", description: Text("点赞、回帖和关注会在这里出现。")) }
            else { List { ForEach(notices) { notice in NotificationRow(notice: notice) }; if notices.isEmpty { ContentUnavailableView("暂时没有动态", systemImage: "bell", description: Text("有人和你互动时会通知你。")) } }.listStyle(.plain).refreshable { await load() }.task { await load() }.toolbar { Button("全部已读") { Task { await markRead() } }.disabled(notices.allSatisfy(\.read)) } }
        }.navigationTitle("动态").alert("加载失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("好", role: .cancel) {} } message: { Text(error ?? "") }
    }
    private func load() async { do { notices = try await api.notifications().notices } catch { self.error = error.localizedDescription } }
    private func markRead() async { do { _ = try await api.markNotificationsRead(); await load() } catch { self.error = error.localizedDescription } }
}

private struct NotificationRow: View {
    let notice: AppNotification
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let actor { AvatarView(user: actor, size: 40) } else { Image(systemName: "gearshape.fill").frame(width: 40, height: 40).background(.secondary.opacity(0.15), in: Circle()) }
            VStack(alignment: .leading, spacing: 4) { Text(title).fontWeight(notice.read ? .regular : .semibold); if !detail.isEmpty { Text(detail).lineLimit(2).foregroundStyle(.secondary) }; Text(relativeTime(notice.createdAt)).font(.caption).foregroundStyle(.tertiary) }
            if !notice.read { Circle().fill(.blue).frame(width: 8, height: 8).padding(.top, 8) }
        }.padding(.vertical, 4)
    }
    private var actor: FeedUser? { notice.actor }
    private var title: String {
        let name = notice.actor?.name ?? "系统"
        switch notice.type {
        case "reply": return "\(name) 回帖了你的帖子"
        case "like": return "\(name) 赞了你的帖子"
        case "repost": return "\(name) 转发了你的帖子"
        case "follow": return "\(name) 关注了你"
        default: return notice.data["title"]?.stringValue ?? "系统通知"
        }
    }
    private var detail: String { notice.comment?.text ?? notice.post?.text ?? notice.data["body"]?.stringValue ?? "" }
}

private extension JSONValue { var stringValue: String? { if case .string(let value) = self { value } else { nil } } }
