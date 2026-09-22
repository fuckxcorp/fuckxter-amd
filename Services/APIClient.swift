import Foundation
import UIKit

enum APIError: LocalizedError { case message(String); case invalidResponse
    var errorDescription: String? { switch self { case .message(let text): text; case .invalidResponse: "服务器响应无效。" } }
}

@MainActor
final class APIClient: ObservableObject {
    static let shared = APIClient()
    /// Canvas 使用独立实例，避免预览等待真实登录会话与网络请求。
    static let preview = APIClient(isLoadingSession: false)
    @Published private(set) var account: Account?
    @Published private(set) var isLoadingSession: Bool
    private let baseURL = URL(string: "https://api.fuckxter.site")!
    private let session: URLSession
    private let decoder: JSONDecoder = JSONDecoder()

    private init(isLoadingSession: Bool = true) {
        self.isLoadingSession = isLoadingSession
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = .shared
        config.httpShouldSetCookies = true
        session = URLSession(configuration: config)
    }

    func bootstrap() async { defer { isLoadingSession = false }; account = try? await request("/auth/me", as: AccountResponse.self).account }
    func signIn(identifier: String, password: String, code: String? = nil, recoveryCode: String? = nil) async throws -> AccountResponse {
        let response: AccountResponse = try await request("/auth/login", method: "POST", body: ["identifier": identifier, "password": password, "code": code, "recoveryCode": recoveryCode])
        account = response.account; return response
    }
    func signOut() async { let _: Empty? = try? await request("/auth/logout", method: "POST"); account = nil }
    func timeline(_ tab: TimelineTab, cursor: String? = nil) async throws -> FeedPage { try await request("/timeline?tab=\(tab.rawValue)&limit=20\(cursor.map { "&cursor=\($0)" } ?? "")") }
    func search(_ query: String) async throws -> SearchResult { try await request("/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") }
    func createPost(text: String, mediaId: String? = nil, visibility: String = "public") async throws -> Post { try await request("/posts", method: "POST", body: ["text": text, "mediaId": mediaId, "visibility": visibility]) }
    func uploadMedia(_ image: UIImage) async throws -> PostMedia {
        guard let data = image.jpegData(compressionQuality: 0.88) else { throw APIError.message("无法处理图片。") }
        return try await request("/media", method: "POST", rawBody: data, headers: ["Content-Type": "image/jpeg", "X-File-Name": "photo.jpg"], as: MediaResponse.self).media
    }
    func like(_ post: Post, enabled: Bool) async throws -> LikeResult { try await request("/posts/\(post.id)/like", method: enabled ? "PUT" : "DELETE") }
    func repost(_ post: Post, enabled: Bool) async throws -> RepostResult { try await request("/posts/\(post.id)/repost", method: enabled ? "PUT" : "DELETE") }
    func save(_ post: Post, enabled: Bool) async throws -> [Post] { try await request("/posts/\(post.id)/save", method: enabled ? "PUT" : "DELETE", as: SavedResponse.self).posts }
    func post(handle: String, slug: String) async throws -> Post { try await request("/posts/\(handle)/\(slug)") }
    func comments(postID: String) async throws -> CommentPage { try await request("/posts/\(postID)/comments") }
    func comment(postID: String, text: String, parentID: String? = nil) async throws -> Comment { try await request("/posts/\(postID)/comments", method: "POST", body: ["text": text, "parentId": parentID], as: CommentResponse.self).comment }
    func profile(_ handle: String) async throws -> UserProfile { try await request("/users/\(handle)", as: UserProfileResponse.self).user }
    func posts(handle: String) async throws -> [Post] { try await request("/users/\(handle)/posts", as: SavedResponse.self).posts }
    func setFollow(_ handle: String, enabled: Bool) async throws -> FollowResult { try await request("/users/\(handle)/follow", method: enabled ? "PUT" : "DELETE") }
    func setBlock(_ handle: String, enabled: Bool) async throws -> BlockResult { try await request("/users/\(handle)/block", method: enabled ? "PUT" : "DELETE") }
    func saved() async throws -> [Post] { try await request("/me/saved", as: SavedResponse.self).posts }
    func notifications() async throws -> NotificationPage { try await request("/notice") }
    func markNotificationsRead() async throws -> Int { try await request("/notice", method: "POST", body: [String: String](), as: UnreadResponse.self).unread }
    func conversations() async throws -> ConversationsPage { try await request("/messages") }
    func conversation(_ handle: String) async throws -> ConversationPage { try await request("/messages/\(handle)") }
    func sendMessage(_ handle: String, text: String) async throws -> ConversationPage { try await request("/messages/\(handle)", method: "POST", body: ["text": text]) }
    func updateProfile(_ profile: AccountProfile) async throws -> Account { let response: AccountResponse = try await request("/me", method: "PATCH", body: ["name": profile.name, "handle": profile.handle, "bio": profile.bio, "region": profile.region, "gender": profile.gender, "birthday": profile.birthday]); guard let account = response.account else { throw APIError.invalidResponse }; self.account = account; return account }
    func updateDMPermission(_ policy: String) async throws { let response: AccountResponse = try await request("/me/dm-policy", method: "PATCH", body: ["policy": policy]); account = response.account }
    func changePassword(current: String, next: String) async throws { let _: Empty = try await request("/me/password", method: "PUT", body: ["current": current, "next": next]) }
    func deleteAccount() async throws { let _: Empty = try await request("/me", method: "DELETE"); account = nil }

    private func request<T: Decodable>(_ path: String, method: String = "GET", body: [String: Any?]? = nil, rawBody: Data? = nil, headers: [String: String] = [:], as type: T.Type = T.self) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw APIError.invalidResponse }
        var request = URLRequest(url: url); request.httpMethod = method; request.timeoutInterval = method == "GET" ? 15 : 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        if let rawBody { request.httpBody = rawBody } else if let body { request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.httpBody = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 }) }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw APIError.message(decodeError(data) ?? "请求失败（\(http.statusCode)）。") }
        if data.isEmpty, T.self == Empty.self { return Empty() as! T }
        do { return try decoder.decode(T.self, from: data) } catch { throw APIError.message("无法读取服务器响应。") }
    }
    private func decodeError(_ data: Data) -> String? { guard let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }; return ((value["error"] as? [String: Any])?["message"] ?? value["message"]) as? String }
}

private struct Empty: Codable {}
private struct MediaResponse: Codable { let media: PostMedia }
private struct CommentResponse: Codable { let comment: Comment }
private struct UnreadResponse: Codable { let unread: Int }
