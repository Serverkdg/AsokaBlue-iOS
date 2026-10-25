import Foundation
import Combine

class ChatService: ObservableObject {
    static let shared = ChatService()
    
    static let firebaseRTDB = "https://asoka-5afdf-default-rtdb.asia-southeast1.firebasedatabase.app"
    
    @Published var chats: [ChatItem] = []
    @Published var activeMessages: [Message] = []
    @Published var isLoading: Bool = false
    @Published var avatarCache: [String: String] = [:]
    
    private var chatListTimer: Timer?
    private var messageDetailTimer: Timer?
    private var currentActivePeer: String?
    
    init() {
        // Pre-fill registered users from cloud
        fetchRegisteredUsers()
    }
    
    static func getCanonicalRoomId(phone1: String, phone2: String) -> String {
        let norm1 = AuthManager.normalizePhone(phone1)
        let norm2 = AuthManager.normalizePhone(phone2)
        let sorted = [norm1, norm2].sorted()
        return "private_\(sorted[0])_\(sorted[1])"
    }
    
    func startPolling(for myPhone: String) {
        let normMyPhone = AuthManager.normalizePhone(myPhone)
        fetchChats(for: normMyPhone)
        chatListTimer?.invalidate()
        chatListTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            self?.fetchChats(for: normMyPhone)
        }
    }
    
    func stopPolling() {
        chatListTimer?.invalidate()
        chatListTimer = nil
    }
    
    func startMessagePolling(myPhone: String, peerPhone: String) {
        currentActivePeer = peerPhone
        fetchMessages(myPhone: myPhone, peerPhone: peerPhone)
        messageDetailTimer?.invalidate()
        messageDetailTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            self?.fetchMessages(myPhone: myPhone, peerPhone: peerPhone)
        }
    }
    
    func stopMessagePolling() {
        messageDetailTimer?.invalidate()
        messageDetailTimer = nil
        currentActivePeer = nil
    }
    
    func fetchRegisteredUsers() {
        let urlString = "\(Self.firebaseRTDB)/users.json"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else { return }
            guard let usersDict = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else { return }
            
            var discoveredAvatars: [String: String] = [:]
            for (phone, udata) in usersDict {
                let norm = AuthManager.normalizePhone(phone)
                if let avatar = udata["avatar"] as? String, !avatar.isEmpty {
                    discoveredAvatars[norm] = avatar
                    discoveredAvatars[phone] = avatar
                }
            }
            
            DispatchQueue.main.async {
                self.avatarCache.merge(discoveredAvatars) { (_, new) in new }
                // Update avatar on existing chats
                for i in 0..<self.chats.count {
                    let normPeer = AuthManager.normalizePhone(self.chats[i].peerPhone)
                    if let av = self.avatarCache[normPeer] ?? self.avatarCache[self.chats[i].peerPhone] {
                        self.chats[i].peerAvatar = av
                    }
                }
            }
        }.resume()
    }
    
    func fetchChats(for myPhone: String) {
        let normMyPhone = AuthManager.normalizePhone(myPhone)
        guard !normMyPhone.isEmpty else { return }
        
        let urlString = "\(Self.firebaseRTDB)/user_chats/\(normMyPhone).json"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else { return }
            
            var items: [ChatItem] = []
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
                for (roomId, dict) in json {
                    let peerPhone = self.extractPeerPhone(from: roomId, myPhone: normMyPhone)
                    guard !peerPhone.isEmpty && peerPhone != normMyPhone else { continue }
                    
                    let name = dict["name"] as? String ?? peerPhone
                    let lastMsg = dict["lastMessage"] as? String ?? ""
                    let timestampMs = (dict["timestampMs"] as? NSNumber)?.int64Value ?? Int64(Date().timeIntervalSince1970 * 1000)
                    let avatar = self.avatarCache[peerPhone] ?? self.avatarCache[AuthManager.normalizePhone(peerPhone)]
                    let unread = (dict["unreadCount"] as? NSNumber)?.intValue ?? 0
                    
                    items.append(ChatItem(
                        peerPhone: peerPhone,
                        peerName: name,
                        peerAvatar: avatar,
                        lastMessage: lastMsg,
                        lastMessageTimestamp: timestampMs,
                        unreadCount: unread,
                        isOnline: false
                    ))
                    
                    if avatar == nil {
                        self.fetchUserAvatar(peerPhone: peerPhone)
                    }
                }
            }
            
            // If user_chats is completely empty, populate with registered contacts so user isn't stuck with empty screen
            if items.isEmpty {
                self.fetchContactsFromUsersNode(myPhone: normMyPhone)
                return
            }
            
            items.sort { $0.lastMessageTimestamp > $1.lastMessageTimestamp }
            
            DispatchQueue.main.async {
                if self.chats != items {
                    self.chats = items
                }
            }
        }.resume()
    }
    
    private func fetchContactsFromUsersNode(myPhone: String) {
        let urlString = "\(Self.firebaseRTDB)/users.json"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else { return }
            guard let usersDict = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else { return }
            
            var items: [ChatItem] = []
            for (phone, dict) in usersDict {
                let normPhone = AuthManager.normalizePhone(phone)
                guard normPhone != myPhone && normPhone.count >= 8 else { continue }
                
                let name = dict["name"] as? String ?? normPhone
                let avatar = dict["avatar"] as? String
                let isOnline = dict["online"] as? Bool ?? false
                
                if let avatar = avatar, !avatar.isEmpty {
                    DispatchQueue.main.async {
                        self.avatarCache[normPhone] = avatar
                    }
                }
                
                items.append(ChatItem(
                    peerPhone: normPhone,
                    peerName: name,
                    peerAvatar: avatar,
                    lastMessage: "Kirim pesan ke \(name)",
                    lastMessageTimestamp: Int64(Date().timeIntervalSince1970 * 1000),
                    unreadCount: 0,
                    isOnline: isOnline
                ))
            }
            
            DispatchQueue.main.async {
                if !items.isEmpty && self.chats.isEmpty {
                    self.chats = items
                }
            }
        }.resume()
    }
    
    func fetchUserAvatar(peerPhone: String) {
        let normPeer = AuthManager.normalizePhone(peerPhone)
        guard avatarCache[normPeer] == nil else { return }
        
        let urlString = "\(Self.firebaseRTDB)/users/\(normPeer)/avatar.json"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else { return }
            if let avatarStr = try? JSONSerialization.jsonObject(with: data) as? String, !avatarStr.isEmpty {
                DispatchQueue.main.async {
                    self.avatarCache[normPeer] = avatarStr
                    self.avatarCache[peerPhone] = avatarStr
                    for i in 0..<self.chats.count {
                        if AuthManager.normalizePhone(self.chats[i].peerPhone) == normPeer {
                            self.chats[i].peerAvatar = avatarStr
                        }
                    }
                }
            }
        }.resume()
    }
    
    func fetchMessages(myPhone: String, peerPhone: String) {
        let normMy = AuthManager.normalizePhone(myPhone)
        let normPeer = AuthManager.normalizePhone(peerPhone)
        let roomId = Self.getCanonicalRoomId(phone1: normMy, phone2: normPeer)
        let urlString = "\(Self.firebaseRTDB)/chats/\(roomId)/messages.json"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
                    var messages: [Message] = []
                    for (msgId, dict) in json {
                        let text = dict["text"] as? String ?? dict["message"] as? String ?? ""
                        guard !text.isEmpty || dict["imageUrl"] != nil else { continue }
                        
                        let senderId = dict["senderId"] as? String ?? dict["sender"] as? String ?? ""
                        let normSender = AuthManager.normalizePhone(senderId)
                        let isOutgoing = (normSender == normMy)
                        
                        let timestamp = (dict["timestampMs"] as? NSNumber)?.int64Value ?? 0
                        let typeRaw = dict["type"] as? String ?? "TEXT"
                        let mediaUrl = dict["imageUrl"] as? String ?? dict["imageStorageUrl"] as? String
                        let msgType = MessageType(rawValue: typeRaw) ?? .text
                        
                        messages.append(Message(
                            id: msgId,
                            senderPhone: normSender,
                            receiverPhone: isOutgoing ? normPeer : normMy,
                            text: text,
                            type: msgType,
                            mediaUrl: mediaUrl,
                            timestamp: timestamp,
                            status: .delivered,
                            isOutgoing: isOutgoing
                        ))
                    }
                    
                    messages.sort { $0.timestamp < $1.timestamp }
                    DispatchQueue.main.async {
                        if self.activeMessages != messages {
                            self.activeMessages = messages
                        }
                    }
                }
            } catch {
                // Ignore empty room parse error
            }
        }.resume()
    }
    
    func sendMessage(myPhone: String, peerPhone: String, peerName: String, text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }
        
        let normMy = AuthManager.normalizePhone(myPhone)
        let normPeer = AuthManager.normalizePhone(peerPhone)
        let roomId = Self.getCanonicalRoomId(phone1: normMy, phone2: normPeer)
        
        let timestampMs = Int64(Date().timeIntervalSince1970 * 1000)
        let msgId = "-P\(timestampMs)_\(Int.random(in: 1000...9999))"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let formattedTime = timeFormatter.string(from: Date())
        
        let myDisplayName = AuthManager.shared.currentUser?.name ?? normMy
        
        let newMsg = Message(
            id: msgId,
            senderPhone: normMy,
            receiverPhone: normPeer,
            text: cleanText,
            type: .text,
            mediaUrl: nil,
            timestamp: timestampMs,
            status: .sent,
            isOutgoing: true
        )
        
        self.activeMessages.append(newMsg)
        
        // Update local chats list
        if let idx = chats.firstIndex(where: { AuthManager.normalizePhone($0.peerPhone) == normPeer }) {
            chats[idx].lastMessage = cleanText
            chats[idx].lastMessageTimestamp = timestampMs
        } else {
            chats.insert(ChatItem(
                peerPhone: normPeer,
                peerName: peerName,
                peerAvatar: avatarCache[normPeer],
                lastMessage: cleanText,
                lastMessageTimestamp: timestampMs,
                unreadCount: 0,
                isOnline: true
            ), at: 0)
        }
        
        // 1. Post to /chats/{roomId}/messages/{msgId}.json
        let messagePayload: [String: Any] = [
            "id": msgId,
            "text": cleanText,
            "senderId": normMy,
            "senderName": myDisplayName,
            "timestamp": formattedTime,
            "timestampMs": timestampMs,
            "type": "TEXT",
            "isOutgoing": true,
            "isDelivered": true,
            "isRead": false,
            "delivered": true,
            "read": false,
            "outgoing": true
        ]
        
        let msgUrlString = "\(Self.firebaseRTDB)/chats/\(roomId)/messages/\(msgId).json"
        if let url = URL(string: msgUrlString) {
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: messagePayload)
            URLSession.shared.dataTask(with: request).resume()
        }
        
        // 2. Update user_chats for sender
        let senderChatPayload: [String: Any] = [
            "id": roomId,
            "name": peerName,
            "lastMessage": cleanText,
            "timestamp": formattedTime,
            "timestampMs": timestampMs,
            "isLastOutgoing": true,
            "lastOutgoing": true,
            "lastMessageId": msgId,
            "unreadCount": 0
        ]
        let senderChatUrl = "\(Self.firebaseRTDB)/user_chats/\(normMy)/\(roomId).json"
        if let url = URL(string: senderChatUrl) {
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: senderChatPayload)
            URLSession.shared.dataTask(with: request).resume()
        }
        
        // 3. Update user_chats for recipient
        let recipientChatPayload: [String: Any] = [
            "id": roomId,
            "name": myDisplayName,
            "lastMessage": cleanText,
            "timestamp": formattedTime,
            "timestampMs": timestampMs,
            "isLastOutgoing": false,
            "lastOutgoing": false,
            "lastMessageId": msgId
        ]
        let recipientChatUrl = "\(Self.firebaseRTDB)/user_chats/\(normPeer)/\(roomId).json"
        if let url = URL(string: recipientChatUrl) {
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: recipientChatPayload)
            URLSession.shared.dataTask(with: request).resume()
        }
        
        // 4. Send Android wake-up notification
        let notifPayload: [String: Any] = [
            "id": msgId,
            "roomId": roomId,
            "senderPhone": normMy,
            "senderName": myDisplayName,
            "message": cleanText,
            "timestamp": formattedTime,
            "timestampMs": timestampMs
        ]
        let notifUrl = "\(Self.firebaseRTDB)/notifications/\(normPeer)/\(msgId).json"
        if let url = URL(string: notifUrl) {
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: notifPayload)
            URLSession.shared.dataTask(with: request).resume()
        }
    }
    
    private func extractPeerPhone(from roomId: String, myPhone: String) -> String {
        if roomId.hasPrefix("private_") {
            let stripped = roomId.replacingOccurrences(of: "private_", with: "")
            let parts = stripped.split(separator: "_").map { String($0) }
            for p in parts {
                if AuthManager.normalizePhone(p) != myPhone {
                    return p
                }
            }
            return parts.last ?? ""
        }
        return roomId
    }
}
