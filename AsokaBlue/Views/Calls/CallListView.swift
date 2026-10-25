import SwiftUI

struct CallItemModel: Identifiable {
    let id = UUID()
    let name: String
    let phone: String
    let time: String
    let isVideo: Bool
    let isIncoming: Bool
    let isMissed: Bool
}

struct CallListView: View {
    @State private var calls: [CallItemModel] = [
        CallItemModel(name: "Dukungan Asoka Blue", phone: "6281234567890", time: "Hari ini 09:30", isVideo: false, isIncoming: true, isMissed: false),
        CallItemModel(name: "Amai", phone: "6281288889999", time: "Kemarin 19:15", isVideo: true, isIncoming: false, isMissed: false)
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Riwayat Panggilan")) {
                    ForEach(calls) { call in
                        HStack(spacing: 14) {
                            Circle()
                                .fill(Theme.primaryBlue.opacity(0.15))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text(call.name.prefix(1).uppercased())
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(Theme.primaryBlue)
                                )
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(call.name)
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
                            
                            Button(action: {}) {
                                Image(systemName: call.isVideo ? "video.fill" : "phone.fill")
                                    .foregroundColor(Theme.primaryBlue)
                                    .font(.system(size: 18))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Panggilan")
        }
    }
}
