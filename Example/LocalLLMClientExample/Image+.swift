import SwiftUI
import LocalLLMClient

extension Image {
    init(llm image: LLMInputImage) {
        #if os(macOS)
        self.init(nsImage: image)
        #elseif os(iOS)
        self.init(uiImage: image)
        #endif
    }
}
