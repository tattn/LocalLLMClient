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
}

struct ChatBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        let isUser = message.role == .user

        Text(message.content)
            .padding(12)
            .background(isUser ? Color.accentColor : .gray.opacity(0.2))
            .foregroundColor(isUser ? .white : .primary)
            .cornerRadius(16)
            .frame(maxWidth: 300, alignment: isUser ? .trailing : .leading)
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
    .environment(AI())
}
