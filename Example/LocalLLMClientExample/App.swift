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
            ChatView(viewModel: .init(ai: ai))
        }
        .disabled(ai.loading.isLoading)
        .overlay {
            if ai.loading.isLoading {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        if ai.loading.progress < 1 {
                            ProgressView("Downloading LLM...", value: ai.loading.progress)
                        } else {
                            ProgressView("Loading LLM...")
                        }

                        if ai.loading.progress < 1, ai.loading.model != .default {
                            Button("Cancel", role: .cancel) {
                                ai.cancelDownload()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding()
                }
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AI())
}
