import Foundation
import Contacts
import SwiftUI
import Combine

struct DeviceContact: Identifiable, Equatable {
    let id: String
    let name: String
    let phone: String
    let rawPhone: String
    let thumbnailData: Data?
    
    static func == (lhs: DeviceContact, rhs: DeviceContact) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name && lhs.phone == rhs.phone
    }
}

class ContactManager: ObservableObject {
    static let shared = ContactManager()
    
    @Published var deviceContacts: [DeviceContact] = []
    @Published var contactsMap: [String: String] = [:]
    @Published var isAuthorized: Bool = false
    @Published var isLoading: Bool = false
    
    private let store = CNContactStore()
    
    private init() {
        checkAuthorization()
    }
    
    func checkAuthorization() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized:
            self.isAuthorized = true
            loadDeviceContacts()
        case .notDetermined:
            self.isAuthorized = false
            requestAccess()
        default:
            self.isAuthorized = false
        }
    }
    
    func requestAccess(completion: ((Bool) -> Void)? = nil) {
        store.requestAccess(for: .contacts) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if granted {
                    self?.loadDeviceContacts()
                }
                completion?(granted)
            }
        }
    }
    
    func loadDeviceContacts() {
        guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else { return }
        
        self.isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let keysToFetch: [CNKeyDescriptor] = [
                CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactThumbnailImageDataKey as CNKeyDescriptor,
                CNContactOrganizationNameKey as CNKeyDescriptor
            ]
            
            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            var contactsList: [DeviceContact] = []
            var mapping: [String: String] = [:]
            var seenPhones = Set<String>()
            
            do {
                try self.store.enumerateContacts(with: request) { contact, _ in
                    let fullName = [contact.givenName, contact.familyName]
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    
                    var displayName = fullName
                    if displayName.isEmpty {
                        displayName = contact.organizationName.trimmingCharacters(in: .whitespaces)
                    }
                    if displayName.isEmpty {
                        displayName = "Kontak Tanpa Nama"
                    }
                    
                    for phoneVal in contact.phoneNumbers {
                        let rawStr = phoneVal.value.stringValue
                        let norm = AuthManager.normalizePhone(rawStr)
                        guard norm.count >= 8 else { continue }
                        
                        // Map all format permutations to ensure match
                        mapping[norm] = displayName
                        mapping[rawStr] = displayName
                        
                        let digits = norm.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                        mapping[digits] = displayName
                        
                        if digits.hasPrefix("0") {
                            let withoutZero = String(digits.dropFirst())
                            mapping[withoutZero] = displayName
                            mapping["62" + withoutZero] = displayName
                            mapping["+62" + withoutZero] = displayName
                        } else if digits.hasPrefix("62") {
                            let without62 = String(digits.dropFirst(2))
                            mapping[without62] = displayName
                            mapping["0" + without62] = displayName
                            mapping["+62" + without62] = displayName
                        }
                        
                        if !seenPhones.contains(norm) {
                            seenPhones.insert(norm)
                            contactsList.append(DeviceContact(
                                id: norm,
                                name: displayName,
                                phone: norm,
                                rawPhone: rawStr,
                                thumbnailData: contact.thumbnailImageData
                            ))
                        }
                    }
                }
                
                contactsList.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                
                DispatchQueue.main.async {
                    self.deviceContacts = contactsList
                    self.contactsMap = mapping
                    self.isLoading = false
                    
                    // Refresh names in ChatService
                    ChatService.shared.refreshContactNames()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
    
    func getContactName(for phone: String) -> String? {
        let norm = AuthManager.normalizePhone(phone)
        if let name = contactsMap[norm], !name.isEmpty {
            return name
        }
        if let name = contactsMap[phone], !name.isEmpty {
            return name
        }
        let digits = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if let name = contactsMap[digits], !name.isEmpty {
            return name
        }
        if digits.hasPrefix("0") {
            let withoutZero = String(digits.dropFirst())
            if let name = contactsMap[withoutZero] ?? contactsMap["62" + withoutZero] ?? contactsMap["+62" + withoutZero], !name.isEmpty {
                return name
            }
        } else if digits.hasPrefix("62") {
            let without62 = String(digits.dropFirst(2))
            if let name = contactsMap[without62] ?? contactsMap["0" + without62], !name.isEmpty {
                return name
            }
        }
        return nil
    }
}
