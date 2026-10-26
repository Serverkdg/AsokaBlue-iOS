import SwiftUI

struct CallItemModel: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let phone: String
    let time: String
    let isVideo: Bool
    let isIncoming: Bool
    let isMissed: Bool
}

struct CallListView: View {
    @ObservedObject var contactManager = ContactManager.shared
    @State private var showingNewCallSheet = false
    @State private var callAlertMessage: String?
    @State private var showingAlert = false
    
    @State private var calls: [CallItemModel] = [
        CallItemModel(name: "Dukungan Asoka Blue", phone: "08115055533", time: "Hari ini 09:30", isVideo: false, isIncoming: true, isMissed: false),
        CallItemModel(name: "Padli", phone: "081354716536", time: "Kemarin 19:15", isVideo: true, isIncoming: false, isMissed: false),
        CallItemModel(name: "Ahmad", phone: "081235369107", time: "23/10/26 14:02", isVideo: false, isIncoming: true, isMissed: true)
    ]
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                List {
                    // Create Call Link Section
                    Section {
                        Button(action: {
                            callAlertMessage = "Tautan panggilan dibuat: https://asoka.blue/call/\(UUID().uuidString.prefix(8))\n\nBagikan tautan ini ke teman untuk memulai panggilan grup."
                            showingAlert = true
                        }) {
                            HStack(spacing: 14) {
                                Circle()
                                    .fill(Theme.primaryBlue)
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Image(systemName: "link")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(.white)
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Buat tautan panggilan")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Theme.primaryBlue)
                                    Text("Bagikan tautan untuk panggilan Asoka Blue")
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.textSecondaryLight)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // Recent Calls Section
                    Section(header: Text("Terbaru")) {
                        ForEach(calls) { call in
                            let displayName = contactManager.getContactName(for: call.phone) ?? call.name
                            HStack(spacing: 14) {
                                Circle()
                                    .fill(Theme.primaryBlue.opacity(0.15))
                                    .frame(width: 46, height: 46)
                                    .overlay(
                                        Text(displayName.prefix(1).uppercased())
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(Theme.primaryBlue)
                                    )
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(displayName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(call.isMissed ? .red : Theme.textPrimaryLight)
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: call.isIncoming ? "arrow.down.left" : "arrow.up.right")
                                            .font(.system(size: 11))
                                            .foregroundColor(call.isMissed ? .red : .green)
                                        Text(call.time)
                                            .font(.system(size: 13))
                                            .foregroundColor(Theme.textSecondaryLight)
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    let type = call.isVideo ? "Video HD" : "Suara"
                                    callAlertMessage = "Menghubungkan Panggilan \(type) ke \(displayName)..."
                                    showingAlert = true
                                }) {
                                    Image(systemName: call.isVideo ? "video.fill" : "phone.fill")
                                        .foregroundColor(Theme.primaryBlue)
                                        .font(.system(size: 18))
                                        .padding(8)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                
                // Floating Action Button to start new call
                Button(action: { showingNewCallSheet = true }) {
                    Circle()
                        .fill(Theme.primaryBlue)
                        .frame(width: 56, height: 56)
                        .shadow(color: Theme.primaryBlue.opacity(0.35), radius: 6, x: 0, y: 3)
                        .overlay(
                            Image(systemName: "phone.badge.plus")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                        )
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Panggilan")
            .sheet(isPresented: $showingNewCallSheet) {
                NewCallSheetView(isPresented: $showingNewCallSheet) { contact, isVideo in
                    let type = isVideo ? "Video HD" : "Suara"
                    callAlertMessage = "Menghubungkan Panggilan \(type) ke \(contact.name)..."
                    showingAlert = true
                }
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Panggilan Asoka Blue"),
                    message: Text(callAlertMessage ?? ""),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

struct NewCallSheetView: View {
    @Binding var isPresented: Bool
    @ObservedObject var contactManager = ContactManager.shared
    let onStartCall: (DeviceContact, Bool) -> Void
    
    @State private var searchQuery: String = ""
    
    var filteredContacts: [DeviceContact] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            return contactManager.deviceContacts
        }
        return contactManager.deviceContacts.filter {
            $0.name.localizedCaseInsensitiveContains(q) || $0.phone.contains(q)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.textSecondaryLight)
                    TextField("Cari kontak untuk panggilan...", text: $searchQuery)
                        .font(.system(size: 15))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                List {
                    Section(header: Text("Pilih Kontak")) {
                        if filteredContacts.isEmpty {
                            Text("Tidak ada kontak ditemukan di perangkat.")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.textSecondaryLight)
                                .padding(.vertical, 12)
                        } else {
                            ForEach(filteredContacts) { contact in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Theme.primaryBlue.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Text(contact.name.prefix(1).uppercased())
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(Theme.primaryBlue)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(contact.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(Theme.textPrimaryLight)
                                        Text(contact.rawPhone)
                                            .font(.system(size: 12))
                                            .foregroundColor(Theme.textSecondaryLight)
                                    }
                                    
                                    Spacer()
                                    
                                    // Voice call button
                                    Button(action: {
                                        isPresented = false
                                        onStartCall(contact, false)
                                    }) {
                                        Image(systemName: "phone.fill")
                                            .foregroundColor(Theme.primaryBlue)
                                            .font(.system(size: 16))
                                            .padding(8)
                                    }
                                    
                                    // Video call button
                                    Button(action: {
                                        isPresented = false
                                        onStartCall(contact, true)
                                    }) {
                                        Image(systemName: "video.fill")
                                            .foregroundColor(Theme.primaryBlue)
                                            .font(.system(size: 16))
                                            .padding(8)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Panggilan Baru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Tutup") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
