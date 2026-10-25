import Foundation
import Combine

class ChatService: ObservableObject {
    static let shared = ChatService()
    
    static let firebaseRTDB = "https://asoka-5afdf-default-rtdb.asia-southeast1.firebasedatabase.app"
    
    @Published var chats: [ChatItem] = []
    @Published var activeMessages: [Message] = []
    @Published var isLoading: Bool = false
    
    @Published var avatarCache: [String: String] = [:]
    
    private var timer: Timer?
    
    init() {
        loadMockDataIfNeeded()
    }
    
    func startPolling(for myPhone: String) {
        fetchChats(for: myPhone)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.fetchChats(for: myPhone)
        }
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    func fetchChats(for myPhone: String) {
        guard !myPhone.isEmpty else { return }
        
        let urlString = "\(Self.firebaseRTDB)/user_chats/\(myPhone).json"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
                    var items: [ChatItem] = []
                    for (peerPhone, dict) in json {
                        let name = dict["name"] as? String ?? peerPhone
                        let lastMsg = dict["lastMessage"] as? String ?? ""
                        let timestamp = (dict["timestamp"] as? NSNumber)?.int64Value ?? Int64(Date().timeIntervalSince1970 * 1000)
                        let avatar = dict["avatar"] as? String ?? self.avatarCache[peerPhone]
                        let unread = (dict["unread"] as? NSNumber)?.intValue ?? 0
                        
                        items.append(ChatItem(
                            peerPhone: peerPhone,
                            peerName: name,
                            peerAvatar: avatar,
                            lastMessage: lastMsg,
                            lastMessageTimestamp: timestamp,
                            unreadCount: unread,
                            isOnline: false
                        ))
                        
                        // Fetch avatar if not present
                        if avatar == nil || avatar?.isEmpty == true {
                            self.fetchUserAvatar(peerPhone: peerPhone)
                        }
                    }
                    
                    items.sort { $0.lastMessageTimestamp > $1.lastMessageTimestamp }
                    
                    DispatchQueue.main.async {
                        if !items.isEmpty && self.chats != items {
                            self.chats = items
                        }
                    }
                }
            } catch {
                // Ignore parse errors on empty node
            }
        }.resume()
    }
    
    func fetchUserAvatar(peerPhone: String) {
        guard avatarCache[peerPhone] == nil else { return }
        let urlString = "\(Self.firebaseRTDB)/users/\(peerPhone)/avatar.json"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else { return }
            if let avatarStr = try? JSONSerialization.jsonObject(with: data) as? String, !avatarStr.isEmpty {
                DispatchQueue.main.async {
                    self.avatarCache[peerPhone] = avatarStr
                    if let idx = self.chats.firstIndex(where: { $0.peerPhone == peerPhone }) {
                        self.chats[idx].peerAvatar = avatarStr
                    }
                }
            }
        }.resume()
    }
    
    func fetchMessages(myPhone: String, peerPhone: String) {
        let roomId = getRoomId(myPhone: myPhone, peerPhone: peerPhone)
        let urlString = "\(Self.firebaseRTDB)/messages/\(roomId).json"
        guard let url = URL(string: urlString) else { return }
        
        isLoading = true
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.isLoading = false
            }
            guard let self = self, let data = data, error == nil else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
                    var messages: [Message] = []
                    for (msgId, dict) in json {
                        let sender = dict["sender"] as? String ?? dict["senderPhone"] as? String ?? ""
                        let receiver = dict["receiver"] as? String ?? dict["receiverPhone"] as? String ?? ""
                        let text = dict["text"] as? String ?? dict["message"] as? String ?? ""
                        let timestamp = (dict["timestamp"] as? NSNumber)?.int64Value ?? 0
                        let typeRaw = dict["type"] as? String ?? "TEXT"
                        let mediaUrl = dict["mediaUrl"] as? String
                        
                        let isOutgoing = (sender == myPhone)
                        let msgType = MessageType(rawValue: typeRaw) ?? .text
                        
                        messages.append(Message(
                            id: msgId,
                            senderPhone: sender,
                            receiverPhone: receiver,
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
                        self.activeMessages = messages
                    }
                }
            } catch {
                // Ignore empty room
            }
        }.resume()
    }
    
    func sendMessage(myPhone: String, peerPhone: String, peerName: String, text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let roomId = getRoomId(myPhone: myPhone, peerPhone: peerPhone)
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let msgId = "msg_\(timestamp)"
        
        let newMsg = Message(
            id: msgId,
            senderPhone: myPhone,
            receiverPhone: peerPhone,
            text: text,
            type: .text,
            mediaUrl: nil,
            timestamp: timestamp,
            status: .sent,
            isOutgoing: true
        )
        
        self.activeMessages.append(newMsg)
        
        // Update local chats list
        if let idx = chats.firstIndex(where: { $0.peerPhone == peerPhone }) {
            chats[idx].lastMessage = text
            chats[idx].lastMessageTimestamp = timestamp
        } else {
            chats.insert(ChatItem(
                peerPhone: peerPhone,
                peerName: peerName,
                peerAvatar: nil,
                lastMessage: text,
                lastMessageTimestamp: timestamp,
                unreadCount: 0,
                isOnline: true
            ), at: 0)
        }
        
        // POST to Firebase RTDB
        let payload: [String: Any] = [
            "id": msgId,
            "sender": myPhone,
            "senderPhone": myPhone,
            "receiver": peerPhone,
            "receiverPhone": peerPhone,
            "message": text,
            "text": text,
            "type": "TEXT",
            "timestamp": timestamp,
            "status": "SENT"
        ]
        
        let urlString = "\(Self.firebaseRTDB)/messages/\(roomId)/\(msgId).json"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: request).resume()
        
        // Update user_chats index on Firebase for both sender & receiver
        updateUserChatIndex(user: myPhone, peer: peerPhone, peerName: peerName, lastMsg: text, timestamp: timestamp)
        updateUserChatIndex(user: peerPhone, peer: myPhone, peerName: AuthManager.shared.currentUser?.name ?? myPhone, lastMsg: text, timestamp: timestamp)
    }
    
    private func updateUserChatIndex(user: String, peer: String, peerName: String, lastMsg: String, timestamp: Int64) {
        let payload: [String: Any] = [
            "phone": peer,
            "name": peerName,
            "lastMessage": lastMsg,
            "timestamp": timestamp
        ]
        let urlString = "\(Self.firebaseRTDB)/user_chats/\(user)/\(peer).json"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        URLSession.shared.dataTask(with: request).resume()
    }
    
    func getRoomId(myPhone: String, peerPhone: String) -> String {
        let sorted = [myPhone, peerPhone].sorted()
        return "\(sorted[0])_\(sorted[1])"
    }
    
    private func loadMockDataIfNeeded() {
        if chats.isEmpty {
            chats = [
                ChatItem(peerPhone: "6281234567890", peerName: "Dukungan Asoka Blue", peerAvatar: nil, lastMessage: "Selamat datang di Asoka Blue untuk iOS!", lastMessageTimestamp: Int64(Date().timeIntervalSince1970 * 1000), unreadCount: 1, isOnline: true)
            ]
        }
    }
}
