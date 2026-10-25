import Foundation

struct User: Identifiable, Codable {
    var id: String { phone }
    let phone: String
    var name: String
    var about: String?
    var avatar: String?
    var isOnline: Bool?
    var lastSeen: Int64?
}

enum MessageType: String, Codable {
    case text = "TEXT"
    case image = "IMAGE"
    case audio = "AUDIO"
    case video = "VIDEO"
    case file = "FILE"
    case location = "LOCATION"
    case contact = "CONTACT"
}

enum MessageStatus: String, Codable {
    case sending = "SENDING"
    case sent = "SENT"
    case delivered = "DELIVERED"
    case read = "READ"
}

struct Message: Identifiable, Codable, Equatable {
    var id: String
    var senderPhone: String
    var receiverPhone: String
    var text: String
    var type: MessageType
    var mediaUrl: String?
    var timestamp: Int64
    var status: MessageStatus
    var isOutgoing: Bool
    
    var formattedTime: String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct ChatItem: Identifiable, Codable, Equatable {
    var id: String { peerPhone }
    let peerPhone: String
    var peerName: String
    var peerAvatar: String?
    var lastMessage: String
    var lastMessageTimestamp: Int64
    var unreadCount: Int
    var isOnline: Bool
    
    var formattedTime: String {
        let date = Date(timeIntervalSince1970: TimeInterval(lastMessageTimestamp) / 1000.0)
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(date) {
            return "Kemarin"
        } else {
            formatter.dateFormat = "dd/MM/yy"
        }
        return formatter.string(from: date)
    }
}
