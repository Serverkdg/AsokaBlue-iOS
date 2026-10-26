import SwiftUI

struct StatusListView: View {
    @ObservedObject var statusService = StatusService.shared
    @ObservedObject var authManager = AuthManager.shared
    
    @State private var showingTextComposer = false
    @State private var showingStatusViewer = false
    @State private var selectedGroup: StatusGroup?
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // My Status Section
                        HStack(spacing: 14) {
                            ZStack(alignment: .bottomTrailing) {
                                let myAv = authManager.currentUser?.avatar
                                AvatarView(
                                    name: authManager.currentUser?.name ?? "Saya",
                                    avatarString: myAv,
                                    size: 56
                                )
                                .overlay(
                                    Circle()
                                        .stroke(statusService.myStatusGroup != nil ? Theme.primaryBlue : Color.clear, lineWidth: 3)
                                )
                                
                                Button(action: { showingTextComposer = true }) {
                                    Circle()
                                        .fill(Theme.primaryBlue)
                                        .frame(width: 22, height: 22)
                                        .overlay(
                                            Image(systemName: "plus")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Status Saya")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Theme.textPrimaryLight)
                                
                                if let myGroup = statusService.myStatusGroup, !myGroup.statuses.isEmpty {
                                    Text("\(myGroup.statuses.count) status • \(myGroup.lastTimestamp)")
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.textSecondaryLight)
                                } else {
                                    Text("Ketuk untuk menambahkan pembaruan status")
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.textSecondaryLight)
                                }
                            }
                            
                            Spacer()
                            
                            if statusService.myStatusGroup != nil {
                                Button(action: {
                                    selectedGroup = statusService.myStatusGroup
                                    showingStatusViewer = true
                                }) {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 18))
                                        .foregroundColor(Theme.textSecondaryLight)
                                        .padding(8)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let myGroup = statusService.myStatusGroup, !myGroup.statuses.isEmpty {
                                selectedGroup = myGroup
                                showingStatusViewer = true
                            } else {
                                showingTextComposer = true
                            }
                        }
                        
                        Divider().padding(.leading, 84)
                        
                        // Recent Updates
                        if !statusService.recentUpdates.isEmpty {
                            Text("Pembaruan terkini")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.textSecondaryLight)
                                .padding(.horizontal, 16)
                                .padding(.top, 4)
                            
                            VStack(spacing: 0) {
                                ForEach(statusService.recentUpdates) { group in
                                    StatusRowView(group: group) {
                                        selectedGroup = group
                                        showingStatusViewer = true
                                    }
                                }
                            }
                        }
                        
                        // Viewed Updates
                        if !statusService.viewedUpdates.isEmpty {
                            Text("Pembaruan yang telah dilihat")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.textSecondaryLight)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                            
                            VStack(spacing: 0) {
                                ForEach(statusService.viewedUpdates) { group in
                                    StatusRowView(group: group) {
                                        selectedGroup = group
                                        showingStatusViewer = true
                                    }
                                }
                            }
                        }
                        
                        // Empty State if no status from contacts
                        if statusService.recentUpdates.isEmpty && statusService.viewedUpdates.isEmpty && statusService.myStatusGroup == nil {
                            VStack(spacing: 12) {
                                Image(systemName: "circle.dashed")
                                    .font(.system(size: 48))
                                    .foregroundColor(Theme.primaryBlue.opacity(0.4))
                                    .padding(.top, 40)
                                Text("Belum Ada Pembaruan")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Theme.textPrimaryLight)
                                Text("Pembaruan status dari teman di kontak Anda akan muncul di sini.")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.textSecondaryLight)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
                
                // Floating Action Buttons (Mini FAB for text & FAB for photo)
                VStack(spacing: 12) {
                    Button(action: { showingTextComposer = true }) {
                        Circle()
                            .fill(Color(UIColor.secondarySystemBackground))
                            .frame(width: 44, height: 44)
                            .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                            .overlay(
                                Image(systemName: "pencil")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Theme.textPrimaryLight)
                            )
                    }
                    
                    Button(action: { showingTextComposer = true }) {
                        Circle()
                            .fill(Theme.primaryBlue)
                            .frame(width: 56, height: 56)
                            .shadow(color: Theme.primaryBlue.opacity(0.35), radius: 6, x: 0, y: 3)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Pembaruan")
            .sheet(isPresented: $showingTextComposer) {
                TextStatusComposerView(isPresented: $showingTextComposer)
            }
            .fullScreenCover(item: $selectedGroup) { group in
                StatusViewerFullScreenView(group: group)
            }
        }
    }
}

struct StatusRowView: View {
    let group: StatusGroup
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    AvatarView(name: group.name, avatarString: group.avatar, size: 52)
                    
                    Circle()
                        .stroke(
                            group.hasUnseen ? Theme.primaryBlue : Color.gray.opacity(0.4),
                            style: StrokeStyle(lineWidth: 2.6, dash: group.statuses.count > 1 ? [12, 3] : [])
                        )
                        .frame(width: 58, height: 58)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(group.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.textPrimaryLight)
                    Text(group.lastTimestamp)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondaryLight)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

struct TextStatusComposerView: View {
    @Binding var isPresented: Bool
    @State private var statusText: String = ""
    @State private var selectedColorIdx: Int = 0
    @State private var isSubmitting = false
    
    let colorPalette: [UInt32] = [
        0xFF0084FF, // Asoka Blue
        0xFF0D9488, // Teal
        0xFF8B5CF6, // Purple
        0xFFEC4899, // Pink
        0xFFF59E0B, // Amber
        0xFF10B981, // Emerald
        0xFF334155  // Slate Dark
    ]
    
    var currentColor: Color {
        let val = colorPalette[selectedColorIdx]
        let r = Double((val >> 16) & 0xFF) / 255.0
        let g = Double((val >> 8) & 0xFF) / 255.0
        let b = Double(val & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
    
    var body: some View {
        ZStack {
            currentColor
                .ignoresSafeArea()
            
            VStack {
                // Top Action Bar
                HStack {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                    }
                    
                    Spacer()
                    
                    Button(action: cycleColor) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .padding(12)
                    }
                }
                .padding(.horizontal, 12)
                
                Spacer()
                
                // Centered Text Input
                TextField("Ketik pembaruan status...", text: $statusText)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Spacer()
                
                // Bottom Send Bar
                HStack {
                    Text("Status (Kontak Saya)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.2))
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(width: 48, height: 48)
                    } else {
                        Button(action: submitStatus) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 48, height: 48)
                                .shadow(radius: 4)
                                .overlay(
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(currentColor)
                                )
                        }
                        .disabled(statusText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }
    
    private func cycleColor() {
        selectedColorIdx = (selectedColorIdx + 1) % colorPalette.count
    }
    
    private func submitStatus() {
        let clean = statusText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        
        isSubmitting = true
        StatusService.shared.postTextStatus(text: clean, backgroundColor: colorPalette[selectedColorIdx]) { success in
            isSubmitting = false
            if success {
                isPresented = false
            }
        }
    }
}

struct StatusViewerFullScreenView: View {
    let group: StatusGroup
    @Environment(\.presentationMode) var presentationMode
    
    @State private var currentIndex: Int = 0
    @State private var progress: Double = 0.0
    @State private var timer: Timer?
    
    var currentItem: StatusStoryItem? {
        guard currentIndex < group.statuses.count else { return nil }
        return group.statuses[currentIndex]
    }
    
    var backgroundColor: Color {
        guard let item = currentItem else { return Color.black }
        let val = item.backgroundColor
        let r = Double((val >> 16) & 0xFF) / 255.0
        let g = Double((val >> 8) & 0xFF) / 255.0
        let b = Double(val & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            VStack {
                // Top Progress Bars
                HStack(spacing: 4) {
                    ForEach(0..<group.statuses.count, id: \.self) { idx in
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.35))
                                if idx < currentIndex {
                                    Capsule().fill(Color.white)
                                } else if idx == currentIndex {
                                    Capsule()
                                        .fill(Color.white)
                                        .frame(width: geo.size.width * CGFloat(progress))
                                }
                            }
                        }
                        .frame(height: 3)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 16)
                
                // Author Header
                HStack(spacing: 10) {
                    AvatarView(name: group.name, avatarString: group.avatar, size: 38)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        Text(currentItem?.timestamp ?? "")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                
                Spacer()
                
                // Story Content
                if let item = currentItem {
                    if let imgUrl = item.imageUrl, !imgUrl.isEmpty {
                        // Display Image story if base64 or url
                        Text(item.storyText)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding()
                    } else {
                        Text(item.storyText)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
                
                Spacer()
            }
            
            // Left/Right Tap zones
            HStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { previousStory() }
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { nextStory() }
            }
        }
        .onAppear {
            startStoryTimer()
            markCurrentViewed()
        }
        .onDisappear {
            stopStoryTimer()
        }
    }
    
    private func markCurrentViewed() {
        if let id = currentItem?.id {
            StatusService.shared.markStatusViewed(statusId: id)
        }
    }
    
    private func startStoryTimer() {
        progress = 0.0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            progress += 0.0125
            if progress >= 1.0 {
                nextStory()
            }
        }
    }
    
    private func stopStoryTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func nextStory() {
        if currentIndex + 1 < group.statuses.count {
            currentIndex += 1
            progress = 0.0
            markCurrentViewed()
        } else {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func previousStory() {
        if currentIndex > 0 {
            currentIndex -= 1
            progress = 0.0
            markCurrentViewed()
        }
    }
}
