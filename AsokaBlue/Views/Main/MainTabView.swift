import SwiftUI

struct MainTabView: View {
    @ObservedObject var chatService = ChatService.shared
    
    var totalUnreadCount: Int {
        chatService.chats.reduce(0) { $0 + $1.unreadCount }
    }
    
    var body: some View {
        TabView {
            ChatListView()
                .tabItem {
                    Label("Chat", systemImage: "message.fill")
                }
                .badge(totalUnreadCount > 0 ? totalUnreadCount : 0)
            
            CallListView()
                .tabItem {
                    Label("Panggilan", systemImage: "phone.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Pengaturan", systemImage: "gearshape.fill")
                }
        }
        .accentColor(Theme.primaryBlue)
    }
}
