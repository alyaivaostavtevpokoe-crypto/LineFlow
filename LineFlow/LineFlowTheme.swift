import SwiftUI

struct LineFlowBackground: View {
    let geometry: GeometryProxy

    var body: some View {
        let landscape = geometry.size.width > geometry.size.height
        ZStack {
            Color(red: 28 / 255, green: 28 / 255, blue: 39 / 255)
            Image(landscape ? "lf_background_landscape" : "lf_background_portrait")
                .resizable()
                .scaledToFit()
                .frame(height: geometry.size.height)
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .clipped()
        .ignoresSafeArea()
    }
}

struct AssetButton: View {
    let imageName: String
    let action: () -> Void
    var enabled: Bool = true
    var maxWidth: CGFloat? = nil

    var body: some View {
        Button(action: action) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: maxWidth ?? .infinity)
                .opacity(enabled ? 1 : 0.45)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(Text(imageName))
    }
}

extension View {
    func lineFlowPanel() -> some View {
        self
            .background(Color.white)
            .overlay(Rectangle().stroke(Color.white.opacity(0.9), lineWidth: 2))
    }
}
