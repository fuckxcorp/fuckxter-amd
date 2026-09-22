import SwiftUI

@main
struct FuckXterApp: App {
    @StateObject private var api = APIClient.shared
    var body: some Scene {
        WindowGroup { RootView(usesCanvasData: false).environmentObject(api).task { await api.bootstrap() } }
    }
}
