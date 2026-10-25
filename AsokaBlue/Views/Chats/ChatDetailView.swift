import SwiftUI
import UIKit

struct ChatDetailView: View {
    let peerPhone: String
    let peerName: String
    
    @ObservedObject var chatService = ChatService.shared
    @ObservedObject var authManager = AuthManager.shared
    
    @State private var inputText: String = ""
    @State private var showingCallAlert: Bool = false
    @State private var callAlertMessage: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages Area
            ZStack {
                Theme.chatBackgroundLight
                    .ignoresSafeArea()
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(chatService.activeMessages) { msg in
                                MessageBubbleView(message: msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: chatService.activeMessages.count) { _ in
                        if let lastId = chatService.activeMessages.last?.id {
                            withAnimation(.easeOut(duration: 0.25)) {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let lastId = chatService.activeMessages.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Bottom Input Bar
            HStack(spacing: 10) {
                Button(action: {
                    callAlertMessage = "Fitur kirim foto & dokumen siap diaktifkan."
                    showingCallAlert = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(Theme.primaryBlue)
                }
                
                HStack {
                    TextField("Ketik pesan...", text: $inputText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .background(Color.white)
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.15), lineWidth: 1))
                
                if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Theme.primaryBlue)
                            .clipShape(Circle())
                    }
                } else {
                    Button(action: {
                        callAlertMessage = "Tahan untuk merekam pesan suara (Voice Note)."
                        showingCallAlert = true
                    }) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Theme.primaryBlue)
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white)
            .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: -2)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 10) {
                    let normPeer = AuthManager.normalizePhone(peerPhone)
                    AvatarView(
                        name: peerName,
                        avatarString: chatService.avatarCache[normPeer] ?? chatService.avatarCache[peerPhone],
                        size: 36
                    )
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(peerName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.textPrimaryLight)
                            .lineLimit(1)
                        Text("Online")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: {
                        callAlertMessage = "Memulai panggilan video HD ke \(peerName)..."
                        showingCallAlert = true
                    }) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.primaryBlue)
                    }
                    
                    Button(action: {
                        callAlertMessage = "Memanggil \(peerName) via Panggilan Suara..."
                        showingCallAlert = true
                    }) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.primaryBlue)
                    }
                }
            }
        }
        .onAppear {
            if let myPhone = authManager.currentUser?.phone {
                chatService.startMessagePolling(myPhone: myPhone, peerPhone: peerPhone)
            }
        }
        .onDisappear {
            chatService.stopMessagePolling()
        }
        .alert(isPresented: $showingCallAlert) {
            Alert(title: Text("Asoka Blue"), message: Text(callAlertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func sendMessage() {
        guard let myPhone = authManager.currentUser?.phone else { return }
        let text = inputText
        inputText = ""
        chatService.sendMessage(myPhone: myPhone, peerPhone: peerPhone, peerName: peerName, text: text)
    }
}

struct MessageBubbleView: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isOutgoing {
                Spacer(minLength: 48)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(message.text)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Text(message.formattedTime)
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.8))
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(colors: [Theme.primaryBlue, Theme.darkBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Theme.primaryBlue.opacity(0.2), radius: 4, x: 0, y: 2)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text(message.text)
                        .font(.system(size: 15))
                        .foregroundColor(Theme.textPrimaryLight)
                    
                    Text(message.formattedTime)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textSecondaryLight)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                Spacer(minLength: 48)
            }
        }
    }
}
