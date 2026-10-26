import SwiftUI

struct ChatListView: View {
    @ObservedObject var chatService = ChatService.shared
    @ObservedObject var authManager = AuthManager.shared
    
    @State private var searchQuery: String = ""
    @State private var showingNewChatSheet: Bool = false
    @State private var newChatPhone: String = ""
    @State private var newChatName: String = ""
    
    var filteredChats: [ChatItem] {
        var baseList = chatService.chats
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            baseList = baseList.filter {
                $0.peerName.localizedCaseInsensitiveContains(searchQuery) ||
                $0.peerPhone.contains(searchQuery) ||
                $0.lastMessage.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        
        var unique: [ChatItem] = []
        var seenPhones = Set<String>()
        for chat in baseList {
            let norm = AuthManager.normalizePhone(chat.peerPhone)
            if !seenPhones.contains(norm) {
                seenPhones.insert(norm)
                unique.append(chat)
            }
        }
        return unique
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.textSecondaryLight)
                    TextField("Cari nama atau nomor...", text: $searchQuery)
                        .font(.system(size: 15))
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.textSecondaryLight)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                // Chats List
                if filteredChats.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.primaryBlue.opacity(0.5))
                        Text("Belum ada percakapan")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.textPrimaryLight)
                        Text("Tekan tombol di kanan atas untuk memulai pesan baru.")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textSecondaryLight)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredChats) { chat in
                            NavigationLink(destination: ChatDetailView(peerPhone: chat.peerPhone, peerName: chat.peerName)) {
                                ChatRowView(chat: chat)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                    .listStyle(PlainListStyle())
                    .transaction { $0.animation = nil }
                }
            }
            .navigationTitle("Asoka Blue")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewChatSheet = true }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Theme.primaryBlue)
                    }
                }
            }
            .sheet(isPresented: $showingNewChatSheet) {
                NewChatSheetView(isPresented: $showingNewChatSheet)
            }
            .onAppear {
                if let myPhone = authManager.currentUser?.phone {
                    chatService.startPolling(for: myPhone)
                }
            }
        }
    }
}

struct ChatRowView: View {
    let chat: ChatItem
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                let norm = AuthManager.normalizePhone(chat.peerPhone)
                let av = chat.peerAvatar ?? ChatService.shared.avatarCache[norm] ?? ChatService.shared.avatarCache[chat.peerPhone]
                AvatarView(name: chat.peerName, avatarString: av, size: 50)
                
                if chat.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 13, height: 13)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.peerName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.textPrimaryLight)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(chat.formattedTime)
                        .font(.system(size: 12))
                        .foregroundColor(chat.unreadCount > 0 ? Theme.primaryBlue : Theme.textSecondaryLight)
                }
                
                HStack {
                    Text(chat.lastMessage)
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondaryLight)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if chat.unreadCount > 0 {
                        Text("\(chat.unreadCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.primaryBlue)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct NewChatSheetView: View {
    @Binding var isPresented: Bool
    @ObservedObject var chatService = ChatService.shared
    @ObservedObject var authManager = AuthManager.shared
    
    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Mulai Obrolan Baru")) {
                    TextField("Nama Kontak", text: $name)
                    TextField("Nomor Telepon (08...)", text: $phone)
                        .keyboardType(.phonePad)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }
                
                Section {
                    Button(action: startChat) {
                        HStack {
                            Spacer()
                            Text("Buka Obrolan")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                    .listRowBackground(Theme.primaryBlue)
                }
            }
            .navigationTitle("Pesan Baru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Batal") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func startChat() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhone = AuthManager.normalizePhone(phone.trimmingCharacters(in: .whitespacesAndNewlines))
        
        guard !cleanName.isEmpty else {
            errorMessage = "Mohon isi nama kontak."
            return
        }
        guard cleanPhone.count >= 8 else {
            errorMessage = "Nomor telepon tidak valid."
            return
        }
        
        let av = chatService.avatarCache[cleanPhone] ?? chatService.avatarCache[AuthManager.normalizePhone(cleanPhone)]
        chatService.chats.removeAll { AuthManager.normalizePhone($0.peerPhone) == cleanPhone }
        chatService.chats.insert(ChatItem(
            peerPhone: cleanPhone,
            peerName: cleanName,
            peerAvatar: av,
            lastMessage: "Memulai percakapan baru...",
            lastMessageTimestamp: Int64(Date().timeIntervalSince1970 * 1000),
            unreadCount: 0,
            isOnline: true
        ), at: 0)
        
        if av == nil {
            chatService.fetchUserAvatar(peerPhone: cleanPhone)
        }
        
        isPresented = false
    }
}
