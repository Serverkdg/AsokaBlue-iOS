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
        fetchChats(for: myPhone)
        chatListTimer?.invalidate()
        chatListTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.fetchChats(for: myPhone)
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
        messageDetailTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
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
    
    static func getAllPhoneVariations(for rawPhone: String) -> [String] {
        var variations = Set<String>()
        let norm = AuthManager.normalizePhone(rawPhone)
        if !norm.isEmpty { variations.insert(norm) }
        let clean = rawPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty { variations.insert(clean) }
        
        let digits = clean.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if !digits.isEmpty {
            variations.insert(digits)
            if digits.hasPrefix("0") {
                let withoutZero = String(digits.dropFirst())
                variations.insert("62" + withoutZero)
                variations.insert("+62" + withoutZero)
                variations.insert(withoutZero)
            } else if digits.hasPrefix("62") {
                let without62 = String(digits.dropFirst(2))
                variations.insert("0" + without62)
                variations.insert("+62" + without62)
                variations.insert(without62)
            }
        }
        return Array(variations)
    }
    
    func fetchChats(for myPhone: String) {
        let variations = Self.getAllPhoneVariations(for: myPhone)
        guard !variations.isEmpty else { return }
        
        let normMyPhone = AuthManager.normalizePhone(myPhone)
        let group = DispatchGroup()
        let lock = NSLock()
        var itemsMap: [String: ChatItem] = [:]
        
        for variant in variations {
            guard let url = URL(string: "\(Self.firebaseRTDB)/user_chats/\(variant).json") else { continue }
            group.enter()
            
            URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
                defer { group.leave() }
                guard let self = self, let data = data, error == nil else { return }
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else { return }
                
                for (roomId, dict) in json {
                    let peerIdentifier = self.extractPeerPhone(from: roomId, myPhone: normMyPhone)
                    guard !peerIdentifier.isEmpty else { continue }
                    
                    var name = dict["name"] as? String ?? dict["peerName"] as? String ?? ""
                    let isNumeric = name.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression) == name
                    
                    // Prioritas 1: Asoka AI / Group formatting
                    if peerIdentifier == "asoka_ai" {
                        name = "Asoka AI (Asisten Cerdas)"
                    } else if roomId.hasPrefix("group_") {
                        if name.isEmpty { name = "Grup Asoka" }
                    } else {
                        // Prioritas 2: Nama kontak dari buku telepon perangkat (device contacts)
                        if let deviceName = ContactManager.shared.getContactName(for: peerIdentifier), !deviceName.isEmpty {
                            name = deviceName
                        } else if name.isEmpty || isNumeric {
                            // Prioritas 3: Nama profil terdaftar di Firebase
                            if let cachedName = self.userNamesCache[peerIdentifier], !cachedName.isEmpty {
                                name = cachedName
                            } else if name.isEmpty {
                                name = peerIdentifier
                            }
                        }
                    }
                    
                    let lastMsg = dict["lastMessage"] as? String ?? dict["message"] as? String ?? ""
                    let timestampMs = (dict["timestampMs"] as? NSNumber)?.int64Value ?? Int64(Date().timeIntervalSince1970 * 1000)
                    let avatar = self.avatarCache[peerIdentifier]
                    let unread = (dict["unreadCount"] as? NSNumber)?.intValue ?? 0
                    let isOnline = dict["online"] as? Bool ?? false
                    
                    let item = ChatItem(
                        peerPhone: peerIdentifier,
                        peerName: name,
                        peerAvatar: avatar,
                        lastMessage: lastMsg,
                        lastMessageTimestamp: timestampMs,
                        unreadCount: unread,
                        isOnline: isOnline
                    )
                    
                    lock.lock()
                    if let existing = itemsMap[peerIdentifier] {
                        var merged = item
                        if existing.lastMessageTimestamp > timestampMs {
                            merged.lastMessage = existing.lastMessage
                            merged.lastMessageTimestamp = existing.lastMessageTimestamp
                        }
                        if let devName = ContactManager.shared.getContactName(for: peerIdentifier), !devName.isEmpty {
                            merged.peerName = devName
                        } else {
                            let existingNumeric = existing.peerName.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression) == existing.peerName
                            if !existingNumeric && !existing.peerName.isEmpty {
                                merged.peerName = existing.peerName
                            }
                        }
                        merged.unreadCount = max(existing.unreadCount, unread)
                        itemsMap[peerIdentifier] = merged
                    } else {
                        itemsMap[peerIdentifier] = item
                    }
                    lock.unlock()
                    
                    if avatar == nil && peerIdentifier != "asoka_ai" && !peerIdentifier.hasPrefix("group_") {
                        self.fetchUserAvatar(peerPhone: peerIdentifier)
                    }
                }
            }.resume()
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            var items = Array(itemsMap.values)
            items.sort { $0.lastMessageTimestamp > $1.lastMessageTimestamp }
            if self.chats != items {
                self.chats = items
            }
        }
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
        
        let roomCandidates: [String]
        if peerPhone == "asoka_ai" || peerPhone.contains("asoka_ai") {
            roomCandidates = ["asoka_ai"]
        } else if peerPhone.hasPrefix("group_") {
            roomCandidates = [peerPhone]
        } else {
            let sorted = [normMy, normPeer].sorted()
            let canon = "private_\(sorted[0])_\(sorted[1])"
            let alt1 = "private_\(normPeer)_\(normMy)"
            let alt2 = "private_\(normMy)_\(normPeer)"
            var set = Set<String>()
            set.insert(canon)
            set.insert(alt1)
            set.insert(alt2)
            roomCandidates = Array(set)
        }
        
        let group = DispatchGroup()
        let lock = NSLock()
        var messagesDict: [String: Message] = [:]
        
        for roomId in roomCandidates {
            let urlString = "\(Self.firebaseRTDB)/chats/\(roomId)/messages.json"
            guard let url = URL(string: urlString) else { continue }
            group.enter()
            
            URLSession.shared.dataTask(with: url) { data, _, error in
                defer { group.leave() }
                guard let data = data, error == nil else { return }
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else { return }
                
                for (msgId, dict) in json {
                    let text = dict["text"] as? String ?? dict["message"] as? String ?? dict["caption"] as? String ?? ""
                    let mediaUrl = dict["imageUrl"] as? String ?? dict["imageStorageUrl"] as? String ?? dict["videoUrl"] as? String ?? dict["audioUrl"] as? String
                    guard !text.isEmpty || mediaUrl != nil else { continue }
                    
                    let senderId = dict["senderId"] as? String ?? dict["sender"] as? String ?? ""
                    let normSender = AuthManager.normalizePhone(senderId)
                    let isOutgoing = (normSender == normMy || senderId == myPhone)
                    
                    let timestamp = (dict["timestampMs"] as? NSNumber)?.int64Value ?? Int64(Date().timeIntervalSince1970 * 1000)
                    let typeRaw = (dict["type"] as? String ?? "TEXT").uppercased()
                    let msgType = MessageType(rawValue: typeRaw) ?? (mediaUrl != nil ? .image : .text)
                    
                    let msg = Message(
                        id: msgId,
                        senderPhone: normSender,
                        receiverPhone: isOutgoing ? normPeer : normMy,
                        text: text,
                        type: msgType,
                        mediaUrl: mediaUrl,
                        timestamp: timestamp,
                        status: .delivered,
                        isOutgoing: isOutgoing
                    )
                    
                    lock.lock()
                    messagesDict[msgId] = msg
                    lock.unlock()
                }
            }.resume()
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            var list = Array(messagesDict.values)
            list.sort { $0.timestamp < $1.timestamp }
            if self.activeMessages != list {
                self.activeMessages = list
            }
        }
    }
    
    func sendMessage(myPhone: String, peerPhone: String, peerName: String, text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }
        
        let normMy = AuthManager.normalizePhone(myPhone)
        let normPeer = AuthManager.normalizePhone(peerPhone)
        
        let roomId: String
        if peerPhone == "asoka_ai" || peerPhone.contains("asoka_ai") {
            roomId = "asoka_ai"
        } else if peerPhone.hasPrefix("group_") {
            roomId = peerPhone
        } else {
            roomId = Self.getCanonicalRoomId(phone1: normMy, phone2: normPeer)
        }
        
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
        
        // 1. Post message to Firebase
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
        
        // 2. Update user_chats for sender across all phone variations
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
        
        for myVar in Self.getAllPhoneVariations(for: myPhone) {
            let senderChatUrl = "\(Self.firebaseRTDB)/user_chats/\(myVar)/\(roomId).json"
            if let url = URL(string: senderChatUrl) {
                var request = URLRequest(url: url)
                request.httpMethod = "PATCH"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try? JSONSerialization.data(withJSONObject: senderChatPayload)
                URLSession.shared.dataTask(with: request).resume()
            }
        }
        
        // 3. Update user_chats for recipient (if not AI or group)
        if peerPhone != "asoka_ai" && !peerPhone.hasPrefix("group_") {
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
            
            for peerVar in Self.getAllPhoneVariations(for: peerPhone) {
                let recipientChatUrl = "\(Self.firebaseRTDB)/user_chats/\(peerVar)/\(roomId).json"
                if let url = URL(string: recipientChatUrl) {
                    var request = URLRequest(url: url)
                    request.httpMethod = "PATCH"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try? JSONSerialization.data(withJSONObject: recipientChatPayload)
                    URLSession.shared.dataTask(with: request).resume()
                }
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
    }
    
    private func extractPeerPhone(from roomId: String, myPhone: String) -> String {
        if roomId == "asoka_ai" || roomId.contains("asoka_ai") {
            return "asoka_ai"
        }
        if roomId.hasPrefix("group_") {
            return roomId
        }
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
