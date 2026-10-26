import Foundation
import SwiftUI
import Combine

class StatusService: ObservableObject {
    static let shared = StatusService()
    
    @Published var myStatusGroup: StatusGroup?
    @Published var recentUpdates: [StatusGroup] = []
    @Published var viewedUpdates: [StatusGroup] = []
    @Published var isLoading: Bool = false
    @Published var isPosting: Bool = false
    
    private var timer: Timer?
    private let viewedKey = "asoka_viewed_status_ids"
    
    init() {
        startPolling()
    }
    
    func startPolling() {
        fetchStatuses()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            self?.fetchStatuses()
        }
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    var viewedStatusIds: Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: viewedKey) ?? []
        return Set(array)
    }
    
    func markStatusViewed(statusId: String) {
        var set = viewedStatusIds
        set.insert(statusId)
        UserDefaults.standard.set(Array(set), forKey: viewedKey)
        fetchStatuses()
    }
    
    func fetchStatuses() {
        guard let url = URL(string: "\(ChatService.firebaseRTDB)/statuses.json") else { return }
        let myPhone = AuthManager.shared.currentUser?.phone ?? ""
        let normMy = AuthManager.normalizePhone(myPhone)
        let viewed = viewedStatusIds
        let oneDayAgoMs = Int64(Date().timeIntervalSince1970 * 1000) - (24 * 60 * 60 * 1000)
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else { return }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else { return }
            
            var groupsDict: [String: [StatusStoryItem]] = [:]
            
            for (statusId, dict) in json {
                let createdAt = (dict["createdAt"] as? NSNumber)?.int64Value ?? 0
                guard createdAt >= oneDayAgoMs else { continue }
                
                let phone = dict["phone"] as? String ?? ""
                let norm = AuthManager.normalizePhone(phone)
                guard !norm.isEmpty else { continue }
                
                let name = dict["name"] as? String ?? phone
                let timestamp = dict["timestamp"] as? String ?? "Hari ini"
                let text = dict["storyText"] as? String ?? dict["text"] as? String ?? ""
                let img = dict["imageUrl"] as? String ?? dict["imageStorageUrl"] as? String
                let vid = dict["videoUrl"] as? String
                let aud = dict["audioUrl"] as? String
                let type = dict["type"] as? String ?? (img != nil ? "IMAGE" : "TEXT")
                let bgLong = (dict["backgroundColor"] as? NSNumber)?.int64Value ?? 0xFF0084FF
                let bgUInt32 = UInt32(truncatingIfNeeded: bgLong)
                
                let item = StatusStoryItem(
                    id: statusId,
                    phone: norm,
                    name: name,
                    timestamp: timestamp,
                    storyText: text,
                    imageUrl: img,
                    videoUrl: vid,
                    audioUrl: aud,
                    type: type,
                    backgroundColor: bgUInt32,
                    createdAt: createdAt
                )
                
                if groupsDict[norm] == nil {
                    groupsDict[norm] = []
                }
                groupsDict[norm]?.append(item)
            }
            
            // Build StatusGroups
            var myGroup: StatusGroup? = nil
            var recent: [StatusGroup] = []
            var seen: [StatusGroup] = []
            
            for (normPhone, items) in groupsDict {
                let sortedItems = items.sorted { $0.createdAt < $1.createdAt }
                let isMine = (normPhone == normMy || normPhone == myPhone)
                
                let contactName = isMine ? "Status Saya" : (ContactManager.shared.getContactName(for: normPhone) ?? sortedItems.first?.name ?? normPhone)
                let av = ChatService.shared.avatarCache[normPhone]
                
                let hasUnseen = sortedItems.contains { !viewed.contains($0.id) }
                
                let group = StatusGroup(
                    phone: normPhone,
                    name: contactName,
                    avatar: av,
                    statuses: sortedItems,
                    isMyStatus: isMine,
                    hasUnseen: hasUnseen
                )
                
                if isMine {
                    myGroup = group
                } else if hasUnseen {
                    recent.append(group)
                } else {
                    seen.append(group)
                }
            }
            
            recent.sort { ($0.statuses.last?.createdAt ?? 0) > ($1.statuses.last?.createdAt ?? 0) }
            seen.sort { ($0.statuses.last?.createdAt ?? 0) > ($1.statuses.last?.createdAt ?? 0) }
            
            DispatchQueue.main.async {
                self.myStatusGroup = myGroup
                self.recentUpdates = recent
                self.viewedUpdates = seen
            }
        }.resume()
    }
    
    func postTextStatus(text: String, backgroundColor: UInt32, completion: @escaping (Bool) -> Void) {
        guard let myPhone = AuthManager.shared.currentUser?.phone else {
            completion(false)
            return
        }
        let normMy = AuthManager.normalizePhone(myPhone)
        let myName = AuthManager.shared.currentUser?.name ?? normMy
        
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let newKey = "-S\(nowMs)_\(Int.random(in: 1000...9999))"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "'Hari ini' HH:mm"
        let timeStr = timeFormatter.string(from: Date())
        
        let payload: [String: Any] = [
            "id": newKey,
            "name": myName,
            "phone": normMy,
            "timestamp": timeStr,
            "storyText": text,
            "imageUrl": "",
            "videoUrl": "",
            "audioUrl": "",
            "audioDuration": 0,
            "type": "TEXT",
            "backgroundColor": Int64(backgroundColor),
            "avatarColor": -16743169,
            "createdAt": nowMs
        ]
        
        guard let url = URL(string: "\(ChatService.firebaseRTDB)/statuses/\(newKey).json") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        isPosting = true
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                self?.isPosting = false
                let success = (error == nil)
                if success {
                    self?.fetchStatuses()
                }
                completion(success)
            }
        }.resume()
    }
}
