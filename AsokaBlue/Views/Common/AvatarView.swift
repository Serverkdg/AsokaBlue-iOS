import SwiftUI
import UIKit

struct AvatarView: View {
    let name: String
    let avatarString: String?
    let size: CGFloat
    
    var body: some View {
        Group {
            if let str = avatarString, !str.isEmpty {
                if let image = decodeBase64(str) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else if str.hasPrefix("http"), let url = URL(string: str) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable()
                                .scaledToFill()
                                .frame(width: size, height: size)
                                .clipShape(Circle())
                        } else {
                            placeholderInitial
                        }
                    }
                } else {
                    placeholderInitial
                }
            } else {
                placeholderInitial
            }
        }
        .frame(width: size, height: size)
    }
    
    private var placeholderInitial: some View {
        Circle()
            .fill(LinearGradient(colors: [Theme.primaryBlue.opacity(0.85), Theme.darkBlue], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay(
                Text(name.isEmpty ? "A" : String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundColor(.white)
            )
    }
    
    private func decodeBase64(_ base64Str: String) -> UIImage? {
        var clean = base64Str.trimmingCharacters(in: .whitespacesAndNewlines)
        if let commaIndex = clean.firstIndex(of: ",") {
            clean = String(clean[clean.index(after: commaIndex)...])
        }
        guard let data = Data(base64Encoded: clean, options: [.ignoreUnknownCharacters]) else {
            return nil
        }
        return UIImage(data: data)
    }
}
