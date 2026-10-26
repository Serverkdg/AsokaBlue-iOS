import Foundation
import Combine

class ChatService: ObservableObject {
    static let shared = ChatService()
    
    static let firebaseRTDB = "https://asoka-5afdf-default-rtdb.asia-southeast1.firebasedatabase.app"
    
    @Published var chats: [ChatItem] = []
    @Published var activeMessages: [Message] = []
    @Published var isLoading: Bool = false
    @Published var avatarCache: [String: String] = [:]
    @Published var userNamesCache: [String: String] = [:]
    
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
            var discoveredNames: [String: String] = [:]
            for (phone, udata) in usersDict {
                let norm = AuthManager.normalizePhone(phone)
                if let avatar = udata["avatar"] as? String, !avatar.isEmpty {
                    discoveredAvatars[norm] = avatar
                    discoveredAvatars[phone] = avatar
                }
                if let name = udata["name"] as? String, !name.isEmpty {
                    discoveredNames[norm] = name
                    discoveredNames[phone] = name
                }
            }
            
            DispatchQueue.main.async {
                self.avatarCache.merge(discoveredAvatars) { (_, new) in new }
                self.userNamesCache.merge(discoveredNames) { (_, new) in new }
                
                // Update avatar and names on existing chats
                for i in 0..<self.chats.count {
                    let normPeer = AuthManager.normalizePhone(self.chats[i].peerPhone)
                    if let av = self.avatarCache[normPeer] ?? self.avatarCache[self.chats[i].peerPhone] {
                        self.chats[i].peerAvatar = av
                    }
                    if let devName = ContactManager.shared.getContactName(for: normPeer), !devName.isEmpty {
                        self.chats[i].peerName = devName
                    } else if let realName = self.userNamesCache[normPeer], !realName.isEmpty {
                        let curDigits = self.chats[i].peerName.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                        if curDigits == self.chats[i].peerName || self.chats[i].peerName.isEmpty {
                            self.chats[i].peerName = realName
                        }
                    }
                }
            }
        }.resume()
    }
    
    func refreshContactNames() {
        DispatchQueue.main.async {
            var updated = false
            for i in 0..<self.chats.count {
                let norm = AuthManager.normalizePhone(self.chats[i].peerPhone)
                if let devName = ContactManager.shared.getContactName(for: norm), !devName.isEmpty {
                    if self.chats[i].peerName != devName {
                        self.chats[i].peerName = devName
                        updated = true
                    }
                }
            }
            if updated {
                self.objectWillChange.send()
            }
        }
    }
    
    func fetchChats(for myPhone: String) {
        let normMyPhone = AuthManager.normalizePhone(myPhone)
        guard !normMyPhone.isEmpty else { return }
        
        let urlString = "\(Self.firebaseRTDB)/user_chats/\(normMyPhone).json"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else { return }
            
            var itemsMap: [String: ChatItem] = [:]
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
                for (roomId, dict) in json {
                    let normPeer = self.extractPeerPhone(from: roomId, myPhone: normMyPhone)
                    guard !normPeer.isEmpty && normPeer != normMyPhone && normPeer.count >= 8 else { continue }
                    
                    var name = dict["name"] as? String ?? dict["peerName"] as? String ?? ""
                    let isNumeric = name.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression) == name
                    
                    // Prioritas 1: Nama kontak dari buku telepon perangkat (device contacts)
                    if let deviceName = ContactManager.shared.getContactName(for: normPeer), !deviceName.isEmpty {
                        name = deviceName
                    } else if name.isEmpty || isNumeric {
                        // Prioritas 2: Nama profil terdaftar di Firebase
                        if let cachedName = self.userNamesCache[normPeer], !cachedName.isEmpty {
                            name = cachedName
                        } else if name.isEmpty {
                            name = normPeer
                        }
                    }
                    
                    let lastMsg = dict["lastMessage"] as? String ?? dict["message"] as? String ?? ""
                    let timestampMs = (dict["timestampMs"] as? NSNumber)?.int64Value ?? Int64(Date().timeIntervalSince1970 * 1000)
                    let avatar = self.avatarCache[normPeer]
                    let unread = (dict["unreadCount"] as? NSNumber)?.intValue ?? 0
                    let isOnline = dict["online"] as? Bool ?? false
                    
                    let item = ChatItem(
                        peerPhone: normPeer,
                        peerName: name,
                        peerAvatar: avatar,
                        lastMessage: lastMsg,
                        lastMessageTimestamp: timestampMs,
                        unreadCount: unread,
                        isOnline: isOnline
                    )
                    
                    if let existing = itemsMap[normPeer] {
                        var merged = item
                        if existing.lastMessageTimestamp > timestampMs {
                            merged.lastMessage = existing.lastMessage
                            merged.lastMessageTimestamp = existing.lastMessageTimestamp
                        }
                        if let devName = ContactManager.shared.getContactName(for: normPeer), !devName.isEmpty {
                            merged.peerName = devName
                        } else {
                            let existingNumeric = existing.peerName.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression) == existing.peerName
                            if !existingNumeric && !existing.peerName.isEmpty {
                                merged.peerName = existing.peerName
                            }
                        }
                        merged.unreadCount = max(existing.unreadCount, unread)
                        itemsMap[normPeer] = merged
                    } else {
                        itemsMap[normPeer] = item
                    }
                    
                    if avatar == nil {
                        self.fetchUserAvatar(peerPhone: normPeer)
                    }
                }
            }
            
            var items = Array(itemsMap.values)
            items.sort { $0.lastMessageTimestamp > $1.lastMessageTimestamp }
            
            DispatchQueue.main.async {
                if self.chats != items {
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
            if chats[idx].peerName.isEmpty || chats[idx].peerName == normPeer {
                chats[idx].peerName = peerName
            }
            let updated = chats.remove(at: idx)
            chats.insert(updated, at: 0)
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
        
        var seenPhones = Set<String>()
        chats.removeAll { item in
            let norm = AuthManager.normalizePhone(item.peerPhone)
            if seenPhones.contains(norm) {
                return true
            }
            seenPhones.insert(norm)
            return false
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
        let normMy = AuthManager.normalizePhone(myPhone)
        if roomId.hasPrefix("private_") {
            let stripped = roomId.replacingOccurrences(of: "private_", with: "")
            let parts = stripped.split(separator: "_").map { String($0) }
            for p in parts {
                let normP = AuthManager.normalizePhone(p)
                if normP != normMy {
                    return normP
                }
            }
            return AuthManager.normalizePhone(parts.last ?? "")
        }
        return AuthManager.normalizePhone(roomId)
    }
}
