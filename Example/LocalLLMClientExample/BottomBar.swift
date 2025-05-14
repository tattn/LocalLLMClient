import SwiftUI

struct BottomBar: View {
    @Binding var text: String
    let isGenerating: Bool
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @Environment(AI.self) private var ai

    var body: some View {
        HStack {
            modelMenu

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
        .animation(.default, value: text.isEmpty)
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
}
