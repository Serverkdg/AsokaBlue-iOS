import Foundation
import SwiftUI

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: User?
    
    private let keyPhone = "asoka_user_phone"
    private let keyName = "asoka_user_name"
    private let keyAbout = "asoka_user_about"
    private let keyAvatar = "asoka_user_avatar"
    
    init() {
        checkLoginState()
    }
    
    func checkLoginState() {
        if let rawPhone = UserDefaults.standard.string(forKey: keyPhone), !rawPhone.isEmpty {
            let phone = Self.normalizePhone(rawPhone)
            UserDefaults.standard.set(phone, forKey: keyPhone)
            
            let name = UserDefaults.standard.string(forKey: keyName) ?? "Pengguna Asoka"
            let about = UserDefaults.standard.string(forKey: keyAbout) ?? "Ada di Asoka Blue 💬"
            let avatar = UserDefaults.standard.string(forKey: keyAvatar)
            self.currentUser = User(phone: phone, name: name, about: about, avatar: avatar, isOnline: true)
            self.isLoggedIn = true
            syncProfileFromServer(phone: phone)
        } else {
            self.currentUser = nil
            self.isLoggedIn = false
        }
    }
    
    func login(phone: String, name: String, about: String? = nil, avatar: String? = nil) {
        let normalized = Self.normalizePhone(phone)
        UserDefaults.standard.set(normalized, forKey: keyPhone)
        UserDefaults.standard.set(name, forKey: keyName)
        if let about = about {
            UserDefaults.standard.set(about, forKey: keyAbout)
        }
        if let avatar = avatar {
            UserDefaults.standard.set(avatar, forKey: keyAvatar)
        }
        
        self.currentUser = User(phone: normalized, name: name, about: about, avatar: avatar, isOnline: true)
        self.isLoggedIn = true
        syncProfileFromServer(phone: normalized)
        publishUserPresence(phone: normalized, name: name)
    }
    
    func syncProfileFromServer(phone: String) {
        let normalized = Self.normalizePhone(phone)
        let urlString = "\(ChatService.firebaseRTDB)/users/\(normalized).json"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else { return }
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let name = dict["name"] as? String
                let avatar = dict["avatar"] as? String
                let about = dict["about"] as? String
                
                DispatchQueue.main.async {
                    if let avatar = avatar, !avatar.isEmpty {
                        UserDefaults.standard.set(avatar, forKey: self.keyAvatar)
                        self.currentUser?.avatar = avatar
                        ChatService.shared.avatarCache[normalized] = avatar
                    }
                    if let name = name, !name.isEmpty {
                        UserDefaults.standard.set(name, forKey: self.keyName)
                        self.currentUser?.name = name
                    }
                    if let about = about, !about.isEmpty {
                        UserDefaults.standard.set(about, forKey: self.keyAbout)
                        self.currentUser?.about = about
                    }
                }
            }
        }.resume()
    }
    
    func publishUserPresence(phone: String, name: String) {
        let normalized = Self.normalizePhone(phone)
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let payload: [String: Any] = [
            "name": name,
            "phone": normalized,
            "online": true,
            "lastSeen": now
        ]
        
        let urlString = "\(ChatService.firebaseRTDB)/users/\(normalized).json"
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        URLSession.shared.dataTask(with: request).resume()
    }
    
    func logout() {
        if let phone = currentUser?.phone {
            let normalized = Self.normalizePhone(phone)
            let urlString = "\(ChatService.firebaseRTDB)/users/\(normalized)/online.json"
            if let url = URL(string: urlString) {
                var req = URLRequest(url: url)
                req.httpMethod = "PUT"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = "false".data(using: .utf8)
                URLSession.shared.dataTask(with: req).resume()
            }
        }
        UserDefaults.standard.removeObject(forKey: keyPhone)
        UserDefaults.standard.removeObject(forKey: keyName)
        UserDefaults.standard.removeObject(forKey: keyAbout)
        UserDefaults.standard.removeObject(forKey: keyAvatar)
        self.currentUser = nil
        self.isLoggedIn = false
    }
    
    static func normalizePhone(_ rawPhone: String) -> String {
        let trimmed = rawPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        var digits = trimmed.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if digits.isEmpty { return trimmed }

        if digits.hasPrefix("0062") {
            digits = String(digits.dropFirst(4))
        } else if digits.hasPrefix("62") {
            digits = String(digits.dropFirst(2))
        }

        while digits.hasPrefix("0") {
            digits = String(digits.dropFirst(1))
        }

        if !digits.isEmpty {
            return "0" + digits
        }
        return trimmed
    }
}
