import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text(viewModel.statusText)
                .font(.headline)
                .padding(.bottom, 30)

            Button("Вставьте изображение") {
                viewModel.openImporter()
            }
            
            .padding()
            .background(Color.orange)
            .foregroundColor(.blue)
            .cornerRadius(16)

            if let image = viewModel.inputImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
            }

            Button("Залить контур") {
                viewModel.processImage()
            }
            
            .padding()
            .background(Color.orange)
            .foregroundColor(.blue)
            .cornerRadius(16)
            
            Button("Подбери цвет по алгоритму") {
            }
            
            .padding()
            .background(Color.pink)
            .foregroundColor(.blue)
            .cornerRadius(16)

            if let result = viewModel.resultImage {
                Image(uiImage: result)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
            }

            Spacer()
        }
        .padding()
        .fileImporter(
            isPresented: $viewModel.isImporterPresented,
            allowedContentTypes: [.png],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let firstURL = urls.first {
                    viewModel.handleImportedFile(.success(firstURL))
                } else {
                    viewModel.statusText = "Файл не выбран"
                }
            case .failure(let error):
                viewModel.handleImportedFile(.failure(error))
            }
        }
    }
}

