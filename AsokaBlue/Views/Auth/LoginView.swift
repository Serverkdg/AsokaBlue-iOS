import SwiftUI

struct LoginView: View {
    @ObservedObject var authManager = AuthManager.shared
    @State private var phoneNumber: String = ""
    @State private var fullName: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            Theme.chatBackgroundLight
                .ignoresSafeArea()
            
            VStack(spacing: 28) {
                Spacer()
                
                // Logo & Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Theme.primaryBlue, Theme.darkBlue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 84, height: 84)
                            .shadow(color: Theme.primaryBlue.opacity(0.35), radius: 12, x: 0, y: 6)
                        
                        Image(systemName: "message.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                    
                    Text("Asoka Blue")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Theme.textPrimaryLight)
                    
                    Text("Perpesanan & Panggilan Cepat, Aman, dan Elegan")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondaryLight)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Form Card
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nama Lengkap")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.textSecondaryLight)
                        
                        TextField("Contoh: Budi Santoso", text: $fullName)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nomor Handphone")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.textSecondaryLight)
                        
                        HStack(spacing: 10) {
                            HStack(spacing: 4) {
                                Text("🇮🇩")
                                Text("+62")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Theme.textPrimaryLight)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                            
                            TextField("812-3456-7890", text: $phoneNumber)
                                .keyboardType(.phonePad)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                        }
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                    
                    Button(action: handleLogin) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Lanjut & Masuk")
                                    .font(.system(size: 16, weight: .semibold))
                                Image(systemName: "arrow.right")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LinearGradient(colors: [Theme.primaryBlue, Theme.darkBlue], startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: Theme.primaryBlue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(isLoading)
                }
                .padding(24)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 8)
                .padding(.horizontal, 24)
                
                Spacer()
                
                Text("Dengan masuk, Anda menyetujui Ketentuan Layanan & Kebijakan Privasi Asoka Blue.")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondaryLight)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .padding(.bottom, 16)
            }
        }
    }
    
    private func handleLogin() {
        let cleanName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanName.isEmpty else {
            errorMessage = "Mohon isi nama lengkap Anda."
            return
        }
        
        guard cleanPhone.count >= 8 else {
            errorMessage = "Nomor handphone tidak valid."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            isLoading = false
            authManager.login(phone: cleanPhone, name: cleanName)
        }
    }
}
