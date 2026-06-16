import SwiftUI

struct StartView: View {
    @State private var selectedMode: AppMode = .start

    var body: some View {
        switch selectedMode {
        case .start:
            GeometryReader { geometry in
                ZStack {
                    Color(red: 28 / 255, green: 28 / 255, blue: 39 / 255)
                        .ignoresSafeArea()

                    Image(geometry.size.width > geometry.size.height ? "lf_start_landscape" : "lf_start_portrait")
                        .resizable()
                        .scaledToFit()
                        .frame(height: geometry.size.height)

                    startButtons(in: geometry.size)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            }
            .ignoresSafeArea()

        case .fill:
            ContentView {
                selectedMode = .start
            }

        case .colorPicker:
            ColorPickerFlowView {
                selectedMode = .start
            }
        }
    }

    @ViewBuilder
    private func startButtons(in size: CGSize) -> some View {
        let landscape = size.width > size.height
        let buttonWidth = landscape ? min(size.width * 0.23, 360) : min(size.width * 0.38, 330)

        if landscape {
            HStack(spacing: size.width * 0.08) {
                AssetButton(imageName: "lf_start_fill", action: { selectedMode = .fill }, maxWidth: buttonWidth)
                AssetButton(imageName: "lf_start_color", action: { selectedMode = .colorPicker }, maxWidth: buttonWidth)
            }
            .offset(y: size.height * 0.18)
        } else {
            HStack(spacing: size.width * 0.06) {
                AssetButton(imageName: "lf_start_fill", action: { selectedMode = .fill }, maxWidth: buttonWidth)
                AssetButton(imageName: "lf_start_color", action: { selectedMode = .colorPicker }, maxWidth: buttonWidth)
            }
            .offset(y: size.height * 0.36)
        }
    }
}

