import SwiftUI
import PhotosUI
import LocalLLMClient

struct BottomBar: View {
    @Binding var text: String
    @Binding var attachments: [LLMAttachment]
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
            if !attachments.isEmpty {
                attachmentList
            }
        }
        .animation(.default, value: text.isEmpty)
        .animation(.default, value: attachments.count)
    }

    @ViewBuilder
    private var attachmentList: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(attachments) { attachment in
                    switch attachment.content {
                    case let .image(image):
                        Image(llm: image)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .cornerRadius(8)
                            .contextMenu {
                                Button {
                                    attachments.removeAll { $0.id == attachment.id }
                                } label: {
                                    Text("Remove")
                                }
                            }
                    }
                }
            }
            .frame(height: 60)
        }
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
                        Task {
                            await ai.loadLLM(model)
                        }
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
                attachments.append(.image(image))
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    @Previewable @State var text = ""
    @Previewable @State var attachments: [LLMAttachment] = [
        .imagePreview, .imagePreview2
    ]

    BottomBar(text: $text, attachments: $attachments, isGenerating: false, onSubmit: { _ in }, onCancel: {})
        .environment(AI())
}
