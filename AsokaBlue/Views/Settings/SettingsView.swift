import SwiftUI

struct SettingsView: View {
    @ObservedObject var authManager = AuthManager.shared
    @State private var showingLogoutAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                // Profile Section
                Section {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(LinearGradient(colors: [Theme.primaryBlue, Theme.darkBlue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text(authManager.currentUser?.name.prefix(1).uppercased() ?? "A")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.currentUser?.name ?? "Pengguna Asoka")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Theme.textPrimaryLight)
                            
                            Text("+\(authManager.currentUser?.phone ?? "")")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.textSecondaryLight)
                            
                            Text(authManager.currentUser?.about ?? "Ada di Asoka Blue 💬")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.primaryBlue)
                        }
                    }
                    .padding(.vertical, 6)
                }
                
                // General Settings
                Section(header: Text("Preferensi")) {
                    NavigationLink(destination: Text("Pengaturan Akun")) {
                        Label("Akun & Keamanan", systemImage: "lock.shield.fill")
                    }
                    NavigationLink(destination: Text("Pengaturan Notifikasi")) {
                        Label("Pemberitahuan & Bunyi", systemImage: "bell.badge.fill")
                    }
                    NavigationLink(destination: Text("Pengaturan Chat")) {
                        Label("Tema & Wallpaper Obrolan", systemImage: "message.fill")
                    }
                    NavigationLink(destination: Text("Penyimpanan & Data")) {
                        Label("Penyimpanan & Data", systemImage: "externaldrive.fill")
                    }
                }
                
                // About
                Section(header: Text("Tentang")) {
                    HStack {
                        Label("Versi Aplikasi", systemImage: "info.circle.fill")
                        Spacer()
                        Text("1.0.0 (Build 1)")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Label("Status Server", systemImage: "network")
                        Spacer()
                        Text("Online (VPS)")
                            .foregroundColor(.green)
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                
                // Logout
                Section {
                    Button(action: { showingLogoutAlert = true }) {
                        HStack {
                            Spacer()
                            Text("Keluar dari Akun")
                                .foregroundColor(.red)
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Pengaturan")
            .alert(isPresented: $showingLogoutAlert) {
                Alert(
                    title: Text("Konfirmasi Keluar"),
                    message: Text("Apakah Anda yakin ingin keluar dari akun Asoka Blue di perangkat ini?"),
                    primaryButton: .destructive(Text("Keluar")) {
                        authManager.logout()
                    },
                    secondaryButton: .cancel(Text("Batal"))
                )
            }
        }
    }
}
