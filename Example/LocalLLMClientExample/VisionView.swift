import SwiftUI
import PhotosUI
import LocalLLMClient

struct VisionView: View {
    @State private var viewModel = VisionViewModel()
    @State private var pickedItem: PhotosPickerItem?

    @Environment(AI.self) private var ai

    var body: some View {
        VStack {
            if let image = viewModel.image {
                Group {
#if os(macOS)
                    Image(nsImage: image)
                        .resizable()
#elseif os(iOS)
                    Image(uiImage: image)
                        .resizable()
#endif
                }
                .scaledToFit()
                .padding()
                .overlay(alignment: .topTrailing) {
                    Button {
                        viewModel.image = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white, .gray.opacity(0.5))
                    }
                    .padding(24)
                    .buttonBorderShape(.circle)
                }
            } else {
                Spacer()
            }

            if viewModel.image == nil {
                PhotosPicker(
                    selection: $pickedItem,
                    matching: .images,
                    preferredItemEncoding: .compatible
                ) {
                    VStack {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .padding(8)

                        Text("Select Image")
                    }
                    .padding()
#if os(iOS)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
#endif
                }
                
                Spacer()
            } else {
                ScrollView {
                    Text(viewModel.outputText)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .padding()
                }
                .overlay {
                    if viewModel.isGenerating, viewModel.outputText.isEmpty {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                }
            }

            BottomBar(
                text: $viewModel.inputText,
                isGenerating: viewModel.isGenerating
            ) { _ in
                viewModel.sendMessage(to: ai)
            } onCancel: {
                viewModel.cancelGeneration()
            }
            .padding([.horizontal, .bottom])
        }
        .navigationTitle("Vision")
        .animation(.default, value: viewModel.image)
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            pickedItem = nil
            Task {
                let data = try await item.loadTransferable(type: Data.self)
                guard let data else { return }
                viewModel.image = LLMInputImage(data: data)
            }
        }
    }
}

#Preview {
    NavigationStack {
        VisionView()
    }
    .environment(AI())
}
