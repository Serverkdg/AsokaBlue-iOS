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
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            baseList = baseList.filter { chat in
                let norm = AuthManager.normalizePhone(chat.peerPhone)
                let devName = ContactManager.shared.getContactName(for: norm) ?? ""
                return chat.peerName.localizedCaseInsensitiveContains(query) ||
                    devName.localizedCaseInsensitiveContains(query) ||
                    chat.peerPhone.contains(query) ||
                    chat.lastMessage.localizedCaseInsensitiveContains(query)
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
                            let norm = AuthManager.normalizePhone(chat.peerPhone)
                            let displayName = ContactManager.shared.getContactName(for: norm) ?? chat.peerName
                            NavigationLink(destination: ChatDetailView(peerPhone: chat.peerPhone, peerName: displayName)) {
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
                ContactManager.shared.checkAuthorization()
            }
        }
    }
}

struct ChatRowView: View {
    let chat: ChatItem
    
    var displayName: String {
        let norm = AuthManager.normalizePhone(chat.peerPhone)
        if let devName = ContactManager.shared.getContactName(for: norm), !devName.isEmpty {
            return devName
        }
        return chat.peerName
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                let norm = AuthManager.normalizePhone(chat.peerPhone)
                let av = chat.peerAvatar ?? ChatService.shared.avatarCache[norm] ?? ChatService.shared.avatarCache[chat.peerPhone]
                AvatarView(name: displayName, avatarString: av, size: 50)
                
                if chat.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 13, height: 13)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayName)
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
    @ObservedObject var contactManager = ContactManager.shared
    
    @State private var searchContactQuery: String = ""
    @State private var manualName: String = ""
    @State private var manualPhone: String = ""
    @State private var errorMessage: String?
    @State private var showManualInput: Bool = false
    
    var filteredDeviceContacts: [DeviceContact] {
        let q = searchContactQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            return contactManager.deviceContacts
        }
        return contactManager.deviceContacts.filter {
            $0.name.localizedCaseInsensitiveContains(q) || $0.phone.contains(q) || $0.rawPhone.contains(q)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.textSecondaryLight)
                    TextField("Cari kontak perangkat...", text: $searchContactQuery)
                        .font(.system(size: 15))
                    if !searchContactQuery.isEmpty {
                        Button(action: { searchContactQuery = "" }) {
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
                
                List {
                    // Quick Action: Manual Input Toggle
                    Section {
                        Button(action: { withAnimation { showManualInput.toggle() } }) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Theme.primaryBlue.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Image(systemName: showManualInput ? "chevron.up" : "person.badge.plus")
                                            .foregroundColor(Theme.primaryBlue)
                                            .font(.system(size: 18))
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Input Nomor Telepon Baru")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Theme.primaryBlue)
                                    Text("Ketik nomor jika belum tersimpan di kontak")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.textSecondaryLight)
                                }
                                Spacer()
                            }
                        }
                        
                        if showManualInput {
                            VStack(alignment: .leading, spacing: 10) {
                                TextField("Nama Kontak (contoh: Ahmad)", text: $manualName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                TextField("Nomor Telepon (08...)", text: $manualPhone)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.phonePad)
                                
                                if let err = errorMessage {
                                    Text(err)
                                        .font(.system(size: 12))
                                        .foregroundColor(.red)
                                }
                                
                                Button(action: startManualChat) {
                                    HStack {
                                        Spacer()
                                        Text("Buka Obrolan")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                    .background(Theme.primaryBlue)
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // Device Contacts Section
                    Section(header: Text("Kontak di Perangkat (\(filteredDeviceContacts.count))")) {
                        if !contactManager.isAuthorized {
                            VStack(alignment: .center, spacing: 10) {
                                Image(systemName: "person.crop.circle.badge.questionmark")
                                    .font(.system(size: 40))
                                    .foregroundColor(Theme.primaryBlue)
                                Text("Akses Kontak Perangkat Diperlukan")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Theme.textPrimaryLight)
                                Text("Izinkan akses agar Asoka Blue dapat menampilkan daftar teman dari buku telepon Anda.")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.textSecondaryLight)
                                    .multilineTextAlignment(.center)
                                Button(action: {
                                    contactManager.requestAccess()
                                }) {
                                    Text("Izinkan Akses Kontak")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 8)
                                        .background(Theme.primaryBlue)
                                        .cornerRadius(8)
                                }
                                .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        } else if filteredDeviceContacts.isEmpty {
                            VStack(alignment: .center, spacing: 8) {
                                Text("Tidak ada kontak ditemukan")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Theme.textSecondaryLight)
                                Text("Pastikan kontak sudah tersimpan di perangkat Anda.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondaryLight.opacity(0.8))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        } else {
                            ForEach(filteredDeviceContacts) { contact in
                                Button(action: {
                                    startChat(phone: contact.phone, name: contact.name)
                                }) {
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Theme.primaryBlue.opacity(0.15))
                                            .frame(width: 42, height: 42)
                                            .overlay(
                                                Text(contact.name.prefix(1).uppercased())
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(Theme.primaryBlue)
                                            )
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(contact.name)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(Theme.textPrimaryLight)
                                            Text(contact.rawPhone)
                                                .font(.system(size: 13))
                                                .foregroundColor(Theme.textSecondaryLight)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "message.fill")
                                            .foregroundColor(Theme.primaryBlue.opacity(0.7))
                                            .font(.system(size: 15))
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Pesan Baru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Tutup") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        contactManager.loadDeviceContacts()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15))
                            .foregroundColor(Theme.primaryBlue)
                    }
                }
            }
            .onAppear {
                contactManager.checkAuthorization()
            }
        }
    }
    
    private func startChat(phone: String, name: String) {
        let cleanPhone = AuthManager.normalizePhone(phone)
        guard cleanPhone.count >= 8 else { return }
        
        let av = chatService.avatarCache[cleanPhone] ?? chatService.avatarCache[phone]
        chatService.chats.removeAll { AuthManager.normalizePhone($0.peerPhone) == cleanPhone }
        chatService.chats.insert(ChatItem(
            peerPhone: cleanPhone,
            peerName: name,
            peerAvatar: av,
            lastMessage: "Memulai percakapan...",
            lastMessageTimestamp: Int64(Date().timeIntervalSince1970 * 1000),
            unreadCount: 0,
            isOnline: true
        ), at: 0)
        
        if av == nil {
            chatService.fetchUserAvatar(peerPhone: cleanPhone)
        }
        
        isPresented = false
    }
    
    private func startManualChat() {
        let cleanName = manualName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhone = AuthManager.normalizePhone(manualPhone.trimmingCharacters(in: .whitespacesAndNewlines))
        
        guard !cleanName.isEmpty else {
            errorMessage = "Mohon isi nama kontak."
            return
        }
        guard cleanPhone.count >= 8 else {
            errorMessage = "Nomor telepon tidak valid."
            return
        }
        
        startChat(phone: cleanPhone, name: cleanName)
    }
}
