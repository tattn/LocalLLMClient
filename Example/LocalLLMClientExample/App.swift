import SwiftUI

@main
struct ExampleApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(AI())
        }
    }
}

struct RootView: View {
    @Environment(AI.self) private var ai

    var body: some View {
        NavigationStack {
            ChatView()
        }
        .disabled(ai.isLoading)
        .overlay {
            if ai.isLoading {
                Group {
                    if ai.downloadProgress < 1 {
                        ProgressView("Downloading LLM...", value: ai.downloadProgress)
                    } else {
                        ProgressView("Loading LLM...")
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .onChange(of: ai.model, initial: true) { _, _ in
            Task {
                await ai.loadLLM()
            }
        }
    }
}
