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
        if let phone = UserDefaults.standard.string(forKey: keyPhone), !phone.isEmpty {
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
    }
    
    func syncProfileFromServer(phone: String) {
        let normalized = Self.normalizePhone(phone)
        let urlString = "https://asoka-5afdf-default-rtdb.asia-southeast1.firebasedatabase.app/users/\(normalized).json"
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
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: keyPhone)
        UserDefaults.standard.removeObject(forKey: keyName)
        UserDefaults.standard.removeObject(forKey: keyAbout)
        UserDefaults.standard.removeObject(forKey: keyAvatar)
        self.currentUser = nil
        self.isLoggedIn = false
    }
    
    static func normalizePhone(_ rawPhone: String) -> String {
        let clean = rawPhone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if clean.hasPrefix("08") {
            return "628" + String(clean.dropFirst(2))
        } else if clean.hasPrefix("8") {
            return "628" + String(clean.dropFirst(1))
        } else if clean.hasPrefix("62") {
            return clean
        }
        return clean
    }
}
