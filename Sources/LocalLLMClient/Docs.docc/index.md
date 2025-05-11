# ``LocalLLMClient``

A Swift package to interact with local Large Language Models (LLMs) on Apple platforms.

## Example

```swift
import LocalLLMClient
import LocalLLMClientMLX
import LocalLLMClientUtility

// Download model from Hugging Face
let downloader = FileDownloader(
    source: .huggingFace(id: "mlx-community/Qwen3-1.7B-4bit", globs: .mlx)
)
let modelURL = try await downloader.download { print("Progress: \($0)") }

// Initialize a client with the downloaded model
let client = try await LocalLLMClient.mlx(url: modelURL)

// Generate text
let prompt = "Tell me a story about a cat"
let text = try await client.generateText(from: prompt)
print(text)
```

```swift
// Streaming text
for try await text in try await client.textStream(from: prompt) {
    print(text, terminator: "")
}
```
