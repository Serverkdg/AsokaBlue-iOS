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
        guard lastMessageTimestamp > 0 else { return "" }
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

// MARK: - Status / Stories Model
struct StatusStoryItem: Identifiable, Codable, Equatable {
    let id: String
    let phone: String
    let name: String
    let timestamp: String
    let storyText: String
    let imageUrl: String?
    let videoUrl: String?
    let audioUrl: String?
    let type: String
    let backgroundColor: UInt32
    let createdAt: Int64
    
    var isImage: Bool {
        return type == "IMAGE" || (imageUrl != nil && !imageUrl!.isEmpty)
    }
}

struct StatusGroup: Identifiable, Equatable {
    var id: String { phone }
    let phone: String
    var name: String
    var avatar: String?
    var statuses: [StatusStoryItem]
    var isMyStatus: Bool
    var hasUnseen: Bool
    
    var lastTimestamp: String {
        statuses.last?.timestamp ?? ""
    }
}

// MARK: - Community Model
struct CommunityItem: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var description: String
    var adminPhone: String
    var announcementChatId: String
    var membersCount: Int
    var createdAt: Int64
}

// MARK: - Call History Model
struct CallHistoryItem: Identifiable, Codable, Equatable {
    let id: String
    let peerPhone: String
    let peerName: String
    let timestamp: Int64
    let isVideo: Bool
    let isIncoming: Bool
    let isMissed: Bool
    
    var formattedTime: String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "'Hari ini' HH:mm"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'Kemarin' HH:mm"
        } else {
            formatter.dateFormat = "dd/MM/yy HH:mm"
        }
        return formatter.string(from: date)
    }
}

