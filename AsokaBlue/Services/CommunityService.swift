import Foundation
import SwiftUI
import Combine

class CommunityService: ObservableObject {
    static let shared = CommunityService()
    
    @Published var communities: [CommunityItem] = []
    @Published var isLoading: Bool = false
    
    private var timer: Timer?
    
    init() {
        startPolling()
    }
    
    func startPolling() {
        fetchCommunities()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { [weak self] _ in
            self?.fetchCommunities()
        }
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    func fetchCommunities() {
        guard let myPhone = AuthManager.shared.currentUser?.phone else { return }
        let variations = ChatService.getAllPhoneVariations(for: myPhone)
        
        let group = DispatchGroup()
        let lock = NSLock()
        var commIds = Set<String>()
        
        // Always include default community if available
        commIds.insert("comm_1792305087037")
        
        for variant in variations {
            guard let url = URL(string: "\(ChatService.firebaseRTDB)/user_communities/\(variant).json") else { continue }
            group.enter()
            URLSession.shared.dataTask(with: url) { data, _, _ in
                defer { group.leave() }
                guard let data = data, let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                lock.lock()
                for key in dict.keys {
                    commIds.insert(key)
                }
                lock.unlock()
            }.resume()
        }
        
        group.notify(queue: .global(qos: .userInitiated)) { [weak self] in
            guard let self = self else { return }
            let detailGroup = DispatchGroup()
            var loadedList: [CommunityItem] = []
            
            for cid in commIds {
                guard let url = URL(string: "\(ChatService.firebaseRTDB)/communities/\(cid).json") else { continue }
                detailGroup.enter()
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    defer { detailGroup.leave() }
                    guard let data = data, let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                    
                    let name = dict["name"] as? String ?? "Komunitas Asoka"
                    let desc = dict["description"] as? String ?? ""
                    let admin = dict["adminPhone"] as? String ?? ""
                    let annId = dict["announcementChatId"] as? String ?? "group_ann_\(cid)"
                    let membersList = dict["memberList"] as? [String] ?? []
                    let count = max(1, membersList.count)
                    let created = (dict["createdAt"] as? NSNumber)?.int64Value ?? 0
                    
                    let item = CommunityItem(
                        id: cid,
                        name: name,
                        description: desc,
                        adminPhone: admin,
                        announcementChatId: annId,
                        membersCount: count,
                        createdAt: created
                    )
                    
                    lock.lock()
                    loadedList.append(item)
                    lock.unlock()
                }.resume()
            }
            
            detailGroup.notify(queue: .main) {
                loadedList.sort { $0.createdAt > $1.createdAt }
                self.communities = loadedList
            }
        }
    }
    
    func createCommunity(name: String, description: String, completion: @escaping (Bool) -> Void) {
        guard let myPhone = AuthManager.shared.currentUser?.phone else {
            completion(false)
            return
        }
        let normMy = AuthManager.normalizePhone(myPhone)
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let commId = "comm_\(nowMs)"
        let annChatId = "group_ann_\(commId)"
        
        let payload: [String: Any] = [
            "id": commId,
            "name": name,
            "description": description,
            "adminPhone": normMy,
            "announcementChatId": annChatId,
            "members": normMy,
            "memberList": [normMy],
            "groupIds": "",
            "createdAt": nowMs,
            "avatarColor": -16743169
        ]
        
        guard let url = URL(string: "\(ChatService.firebaseRTDB)/communities/\(commId).json") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: request) { [weak self] _, _, error in
            let success = (error == nil)
            if success {
                // Link in user_communities
                for v in ChatService.getAllPhoneVariations(for: normMy) {
                    let userCommUrl = "\(ChatService.firebaseRTDB)/user_communities/\(v)/\(commId).json"
                    if let u = URL(string: userCommUrl) {
                        var req = URLRequest(url: u)
                        req.httpMethod = "PUT"
                        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        req.httpBody = "true".data(using: .utf8)
                        URLSession.shared.dataTask(with: req).resume()
                    }
                }
            }
            DispatchQueue.main.async {
                if success {
                    self?.fetchCommunities()
                }
                completion(success)
            }
        }.resume()
    }
}
