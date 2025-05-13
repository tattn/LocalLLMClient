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
        TabView {
            NavigationStack {
                ChatView()
            }
            .tabItem {
                Label("Chat", systemImage: "message")
            }

            NavigationStack {
                VisionView()
            }
            .tabItem {
                Label("Vision", systemImage: "photo")
            }
        }
        .disabled(ai.isLoading)
        .overlay {
            if ai.isLoading {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()

                    Group {
                        if ai.downloadProgress < 1 {
                            ProgressView("Downloading LLM...", value: ai.downloadProgress)
                        } else {
                            ProgressView("Loading LLM...")
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding()
                }
            }
        }
#if !targetEnvironment(simulator)
        .onChange(of: ai.model, initial: true) { _, _ in
            Task {
                await ai.loadLLM()
            }
        }
#endif
    }
}

#Preview {
    RootView()
        .environment(AI())
}
