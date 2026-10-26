import SwiftUI

struct MainTabView: View {
    @ObservedObject var chatService = ChatService.shared
    @ObservedObject var statusService = StatusService.shared
    @State private var selectedTab: Int = 0
    
    var totalUnreadCount: Int {
        chatService.chats.reduce(0) { $0 + $1.unreadCount }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ChatListView()
                .tabItem {
                    Label("Chat", systemImage: "message.fill")
                }
                .badge(totalUnreadCount > 0 ? totalUnreadCount : 0)
                .tag(0)
            
            StatusListView()
                .tabItem {
                    Label("Pembaruan", systemImage: "circle.dashed")
                }
                .badge(statusService.recentUpdates.count > 0 ? "•" : nil)
                .tag(1)
            
            CommunityListView()
                .tabItem {
                    Label("Komunitas", systemImage: "person.3.fill")
                }
                .tag(2)
            
            CallListView()
                .tabItem {
                    Label("Panggilan", systemImage: "phone.fill")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label("Pengaturan", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .accentColor(Theme.primaryBlue)
    }
}
