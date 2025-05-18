import SwiftUI
import PhotosUI
import LocalLLMClient

struct BottomBar: View {
    @Binding var text: String
    @Binding var images: [ChatMessage.Image]
    let isGenerating: Bool
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @State private var pickedItem: PhotosPickerItem?
    @Environment(AI.self) private var ai

    var body: some View {
        HStack {
            modelMenu
            imagePicker
                .disabled(!ai.model.supportsVision)

            TextField("Hello", text: $text)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit{
                    onSubmit(text)
                }
                .disabled(isGenerating)

            if isGenerating {
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.red)
                }
            } else if !text.isEmpty {
                Button {
                    onSubmit(text)
                } label: {
                    Image(systemName: "arrow.up")
                        .foregroundStyle(text.isEmpty ? .gray : .accentColor)
                }
                .buttonBorderShape(.circle)
                .keyboardShortcut(.defaultAction)
            }
        }
        .safeAreaInset(edge: .top) {
            if !images.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(images) { image in
                            Image(llm: image.value)
                                .resizable()
                                .aspectRatio(1, contentMode: .fill)
                                .cornerRadius(8)
                                .contextMenu {
                                    Button {
                                        images.removeAll { $0.id == image.id }
                                    } label: {
                                        Text("Remove")
                                    }
                                }
                        }
                    }
                    .frame(height: 60)
                }
            }
        }
        .animation(.default, value: text.isEmpty)
        .animation(.default, value: images.count)
    }

    @ViewBuilder
    private var modelMenu: some View {
#if os(macOS)
            @Bindable var ai = ai
            Picker(selection: $ai.model) {
                ForEach(LLMModel.allCases) { model in
                    Group {
                        if model.supportsVision {
                            Text("\(model.name) [VLM]")
                        } else {
                            Text(model.name)
                        }
                    }
                    .tag(model)
                }
            } label: {
                Image(systemName: "brain.head.profile")
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize(horizontal: true, vertical: false)
#elseif os(iOS)
            Menu {
                ForEach(LLMModel.allCases) { model in
                    Button {
                        ai.model = model
                    } label: {
                        if model.supportsVision {
                            Text("\(model.name) [VLM]")
                        } else {
                            Text(model.name)
                        }
                        if ai.model == model {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                Image(systemName: "brain.head.profile")
            }
            .menuStyle(.button)
#endif
    }

    @ViewBuilder
    private var imagePicker: some View {
        PhotosPicker(
            selection: $pickedItem,
            matching: .images,
            preferredItemEncoding: .compatible
        ) {
            Image(systemName: "photo")
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            pickedItem = nil
            Task {
                let data = try await item.loadTransferable(type: Data.self)
                guard let data, let image = LLMInputImage(data: data) else { return }
                images.append(.init(value: image))
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    @Previewable @State var text = ""
    @Previewable @State var images: [ChatMessage.Image] = [
        .preview, .preview2
    ]

    BottomBar(text: $text, images: $images, isGenerating: false, onSubmit: { _ in }, onCancel: {})
        .environment(AI())
}
