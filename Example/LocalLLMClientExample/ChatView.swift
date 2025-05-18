import SwiftUI
import LocalLLMClient
import LocalLLMClientMLX

struct ChatView: View {
    @State var viewModel = ChatViewModel()
    @State private var position = ScrollPosition(idType: ChatMessage.ID.self)

    @Environment(AI.self) private var ai

    var body: some View {
        VStack {
            messageList

            BottomBar(
                text: $viewModel.inputText,
                images: $viewModel.inputImages,
                isGenerating: viewModel.isGenerating
            ) { _ in
                viewModel.sendMessage(to: ai)
            } onCancel: {
                viewModel.cancelGeneration()
            }
            .padding([.horizontal, .bottom])
        }
        .navigationTitle("Chat")
        .toolbar {
            ToolbarItem {
                Menu {
                    Button("Clear Chat") {
                        viewModel.clearMessages()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
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

        VStack(alignment: isUser ? .trailing : .leading) {
            LazyVGrid(columns: [.init(.adaptive(minimum: 100))], alignment: .leading) {
                ForEach(message.images) { image in
                    Image(llm: image.value)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(16)
                }
                .scaleEffect(x: isUser ? -1 : 1)
            }
            .scaleEffect(x: isUser ? -1 : 1)

            Text(message.text)
                .padding(12)
                .background(isUser ? Color.accentColor : .gray.opacity(0.2))
                .foregroundColor(isUser ? .white : .primary)
                .cornerRadius(16)
        }
        .padding(isUser ? .leading : .trailing, 50)
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}

#Preview("Text") {
    NavigationStack {
        ChatView(viewModel: .init(messages: [
            .init(role: .user, text: "Hello"),
            .init(role: .assistant, text: "Hi! How can I help you?"),
            .init(role: .user, text: "Hello", images: [.preview, .preview2]),
        ]))
    }
    .environment(AI())
}

extension ChatMessage.Image {
    static let preview = try! Self.init(value: LLMInputImage(data: .init(contentsOf: URL(string: "https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/cats.jpeg")!))!)
    static let preview2 = try! Self.init(value: LLMInputImage(data: .init(contentsOf: URL(string: "https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/robot.png")!))!)
}
