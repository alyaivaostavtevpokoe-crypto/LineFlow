//
//  StartView.swift
//  LineFlow
//
//  Created by macbook Алиса on 20/5/26.
//

import SwiftUI

struct StartView: View {
    @State private var selectedMode: AppMode = .start

    var body: some View {
        switch selectedMode {
        case .start:
            VStack(spacing: 24) {
                Text("LineFlow")
                    .font(.largeTitle)
                    .bold()

                Button("Создать заливку") {
                    selectedMode = .fill
                }
                .mainStartButton(background: .orange, foreground: .blue)

                Button("Подобрать цвет") {
                    selectedMode = .colorPicker
                }
                .mainStartButton(background: .purple, foreground: .white)
            }
            .padding()

        case .fill:
            ContentView()

        case .colorPicker:
            ColorPickerFlowView {
                selectedMode = .start
            }
        }
    }
}

private extension View {
    func mainStartButton(background: Color, foreground: Color) -> some View {
        self
            .frame(maxWidth: .infinity)
            .padding()
            .background(background)
            .foregroundColor(foreground)
            .cornerRadius(18)
            .font(.headline)
    }
}
