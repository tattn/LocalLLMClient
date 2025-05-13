import SwiftUI
import LocalLLMClient
import LocalLLMClientMLX

struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    @State private var position = ScrollPosition(idType: ChatMessage.ID.self)

    @Environment(AI.self) private var ai

    var body: some View {
        VStack {
            messageList

            bottomBar
                .padding([.horizontal, .bottom])
        }
        .navigationTitle("Chat")
        .onChange(of: ai.model) { _, _ in
            viewModel.clearMessages()
        }
    }

    @ViewBuilder
    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.messages) { message in
                    ChatBubbleView(message: message)
                        .id(message.id)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal)
        }
        .onChange(of: viewModel.messages) { _, _ in
            withAnimation {
                position.scrollTo(edge: .bottom)
            }
        }
        .scrollPosition($position)
    }

    @ViewBuilder
    private var bottomBar: some View {
        HStack {
#if os(macOS)
            @Bindable var ai = ai
            Picker(selection: $ai.model) {
                ForEach(LLMModel.allCases) { model in
                    Text(model.name)
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
                        Text(model.name)
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

            TextField("Hello", text: $viewModel.inputText)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit{
                    viewModel.sendMessage(to: ai)
                }
                .disabled(viewModel.isGenerating)

            if viewModel.isGenerating {
                Button {
                    viewModel.cancelGeneration()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.red)
                }
            } else if !viewModel.inputText.isEmpty {
                Button {
                    viewModel.sendMessage(to: ai)
                } label: {
                    Image(systemName: "arrow.up")
                        .foregroundStyle(viewModel.inputText.isEmpty ? .gray : .accentColor)
                }
                .buttonBorderShape(.circle)
                .keyboardShortcut(.defaultAction)
            }
        }
        .animation(.default, value: viewModel.inputText.isEmpty)
    }
}

struct ChatBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            let isUser = message.role == .user

            VStack(alignment: isUser ? .trailing : .leading) {
                Text(message.content)
                    .padding(12)
                    .background(isUser ? Color.accentColor : .gray.opacity(0.2))
                    .foregroundColor(isUser ? .white : .primary)
                    .cornerRadius(16)
            }
            .frame(maxWidth: 300, alignment: isUser ? .trailing : .leading)
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        }
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
    .environment(AI())
}
