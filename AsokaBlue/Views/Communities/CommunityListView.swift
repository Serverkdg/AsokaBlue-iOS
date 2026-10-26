import SwiftUI

struct CommunityListView: View {
    @ObservedObject var communityService = CommunityService.shared
    @State private var showingCreateSheet = false
    
    var body: some View {
        NavigationView {
            List {
                // Hero Section: New Community
                Section {
                    Button(action: { showingCreateSheet = true }) {
                        HStack(spacing: 14) {
                            ZStack(alignment: .bottomTrailing) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Theme.primaryBlue.opacity(0.12))
                                    .frame(width: 52, height: 52)
                                    .overlay(
                                        Image(systemName: "person.3.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(Theme.primaryBlue)
                                    )
                                
                                Circle()
                                    .fill(Theme.primaryBlue)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Image(systemName: "plus")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                    .offset(x: 2, y: 2)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Komunitas baru")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Theme.textPrimaryLight)
                                Text("Satukan grup dan pengumuman terkait di satu tempat")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondaryLight)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Existing Communities List
                if !communityService.communities.isEmpty {
                    ForEach(communityService.communities) { comm in
                        Section {
                            // Community Header
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Theme.primaryBlue)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Text(comm.name.prefix(1).uppercased())
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(comm.name)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Theme.textPrimaryLight)
                                    if !comm.description.isEmpty {
                                        Text(comm.description)
                                            .font(.system(size: 12))
                                            .foregroundColor(Theme.textSecondaryLight)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            
                            // Announcement Channel Link
                            NavigationLink(destination: ChatDetailView(peerPhone: comm.announcementChatId, peerName: "\(comm.name) (Pengumuman)")) {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Theme.primaryBlue.opacity(0.15))
                                        .frame(width: 38, height: 38)
                                        .overlay(
                                            Image(systemName: "megaphone.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(Theme.primaryBlue)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Pengumuman")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(Theme.textPrimaryLight)
                                        Text("Saluran resmi pengumuman komunitas")
                                            .font(.system(size: 12))
                                            .foregroundColor(Theme.textSecondaryLight)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                } else {
                    Section {
                        VStack(spacing: 10) {
                            Text("Belum Ada Komunitas")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Theme.textPrimaryLight)
                            Text("Buat komunitas baru untuk mengumpulkan grup yang memiliki topik serupa.")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSecondaryLight)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Komunitas")
            .sheet(isPresented: $showingCreateSheet) {
                CreateCommunitySheetView(isPresented: $showingCreateSheet)
            }
        }
    }
}

struct CreateCommunitySheetView: View {
    @Binding var isPresented: Bool
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Informasi Komunitas")) {
                    TextField("Nama Komunitas (contoh: Warga Komplek)", text: $name)
                    TextField("Deskripsi Komunitas", text: $description)
                }
                
                if let err = errorMessage {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }
                
                Section {
                    Button(action: submitCommunity) {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Buat Komunitas")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                    }
                    .listRowBackground(Theme.primaryBlue)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
            }
            .navigationTitle("Komunitas Baru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Batal") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func submitCommunity() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            errorMessage = "Mohon isi nama komunitas."
            return
        }
        
        isSubmitting = true
        CommunityService.shared.createCommunity(name: cleanName, description: description.trimmingCharacters(in: .whitespacesAndNewlines)) { success in
            isSubmitting = false
            if success {
                isPresented = false
            } else {
                errorMessage = "Gagal membuat komunitas. Coba lagi."
            }
        }
    }
}
