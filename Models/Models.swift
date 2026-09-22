import Foundation

enum TimelineTab: String, CaseIterable, Identifiable {
    case foryou, latest, following
    var id: String { rawValue }
    var title: String {
        switch self { case .foryou: "推荐"; case .latest: "实时"; case .following: "关注" }
    }
}

struct FeedUser: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let handle: String
    let verified: Bool?
    let avatarUrl: String?
}

struct PostStats: Codable, Hashable { let replies: Int; let reposts: Int; let likes: Int; let views: Int }
struct PostMedia: Codable, Hashable { let id: String; let url: String; let alt: String; let contentType: String; let byteSize: Int; let hdr: Bool? }
struct PostViewer: Codable, Hashable { let liked: Bool; let reposted: Bool; let saved: Bool; let followingAuthor: Bool?; let isAuthor: Bool? }

struct Post: Codable, Identifiable, Hashable {
    let id: String
    let slug: String
    let author: FeedUser
    let text: String
    let createdAt: String
    let visibility: String?
    var stats: PostStats
    let media: PostMedia?
    var viewer: PostViewer?
}

struct FeedPage: Codable { let tab: String; let posts: [Post]; let nextCursor: String? }
struct UserStats: Codable, Hashable { let posts: Int; let followers: Int; let following: Int }
struct UserSummary: Codable, Identifiable, Hashable { let id: String; let name: String; let handle: String; let verified: Bool?; let bio: String; let avatarUrl: String?; let createdAt: String; let stats: UserStats }
struct UserViewer: Codable, Hashable { let following: Bool; let blocked: Bool?; let canMessage: Bool? }
struct UserProfile: Codable, Hashable {
    let id: String; let handle: String; let name: String; let verified: Bool?; let bio: String
    let region: String; let gender: String; let birthday: String; let createdAt: String
    let avatarUrl: String?; let headerUrl: String?; var stats: UserStats; var viewer: UserViewer; let deleted: Bool?
}
struct UserProfileResponse: Codable { let user: UserProfile }

struct CommentStats: Codable, Hashable { let likes: Int; let reposts: Int }
struct CommentViewer: Codable, Hashable { let liked: Bool; let reposted: Bool }
struct Comment: Codable, Identifiable, Hashable { let id: String; let author: FeedUser; let text: String; let createdAt: String; let stats: CommentStats; let viewer: CommentViewer }
struct CommentPage: Codable { let comments: [Comment]; let total: Int }

struct AccountProfile: Codable, Hashable { let name: String; let handle: String; let bio: String; let email: String; let region: String; let gender: String; let birthday: String }
struct Account: Codable, Hashable { let profile: AccountProfile; let avatarUrl: String?; let headerUrl: String?; let twoFactorEnabled: Bool; let recoveryCodeCount: Int; let dmPolicy: String?; let createdAt: String }
struct AccountResponse: Codable { let account: Account?; let restored: Bool? }

struct SearchResult: Codable { let query: String; let users: [UserSummary]; let posts: [Post] }
struct LikeResult: Codable { let id: String; let liked: Bool; let likes: Int }
struct RepostResult: Codable { let id: String; let reposted: Bool; let reposts: Int }
struct SavedResponse: Codable { let posts: [Post] }
struct FollowResult: Codable { let handle: String; let following: Bool; let followers: Int }
struct BlockResult: Codable { let handle: String; let blocked: Bool }

struct DirectMessage: Codable, Identifiable, Hashable { let id: String; let body: String; let createdAt: String; let mine: Bool; let read: Bool }
struct Conversation: Codable, Identifiable, Hashable { let id: String; let other: FeedUser; let lastMessageAt: String; let unread: Int; let lastMessage: LastMessage? }
struct LastMessage: Codable, Hashable { let body: String; let mine: Bool; let createdAt: String }
struct ConversationsPage: Codable { let threads: [Conversation]; let unread: Int }
struct ConversationPage: Codable { let user: FeedUser; let messages: [DirectMessage]; let unread: Int; let canSend: Bool?; let dmPolicy: String?; let hint: String? }

struct AppNotification: Codable, Identifiable, Hashable { let id: String; let type: String; let createdAt: String; let read: Bool; let actor: FeedUser?; let post: NotificationPost?; let comment: NotificationComment?; let data: [String: JSONValue] }
struct NotificationPost: Codable, Hashable { let id: String; let slug: String; let authorHandle: String; let text: String }
struct NotificationComment: Codable, Hashable { let id: String; let text: String }
struct NotificationPage: Codable { let notices: [AppNotification]; let nextCursor: String?; let unread: Int }

enum JSONValue: Codable, Hashable { case string(String), number(Double), bool(Bool), object([String: JSONValue]), array([JSONValue]), null
    init(from decoder: Decoder) throws { let c = try decoder.singleValueContainer(); if c.decodeNil() { self = .null } else if let v = try? c.decode(Bool.self) { self = .bool(v) } else if let v = try? c.decode(Double.self) { self = .number(v) } else if let v = try? c.decode(String.self) { self = .string(v) } else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) } else { self = .array(try c.decode([JSONValue].self)) } }
    func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); switch self { case .string(let v): try c.encode(v); case .number(let v): try c.encode(v); case .bool(let v): try c.encode(v); case .object(let v): try c.encode(v); case .array(let v): try c.encode(v); case .null: try c.encodeNil() } }
}
