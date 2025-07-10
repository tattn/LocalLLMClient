# LocalLLMClient

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/tattn/LocalLLMClient/actions/workflows/test.yml/badge.svg)](https://github.com/tattn/LocalLLMClient/actions/workflows/test.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ftattn%2FLocalLLMClient%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/tattn/LocalLLMClient)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ftattn%2FLocalLLMClient%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/tattn/LocalLLMClient)


A Swift package to interact with local Large Language Models (LLMs) on Apple platforms.

<table>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/f949ba1d-f063-463c-a6fa-dcdf14c01e8b" width="100%" alt="example on iOS" /></td>
    <td><img src="https://github.com/user-attachments/assets/3ac6aef5-df1a-45e9-8989-e4dbce223ceb" width="100%" alt="example on macOS" /></td>
  </tr>
</table>

<details>
<summary>Demo / Multimodal</summary>

| MobileVLM-3B (llama.cpp) | Qwen2.5 VL 3B (MLX) |
|:-:|:-:|
|<video src="https://github.com/user-attachments/assets/7704b05c-2a8c-40ef-838c-f9485ad0cfe0">|<video src="https://github.com/user-attachments/assets/475609a4-aaef-4043-aadc-db44c28296ee">|

*iPhone 16 Pro*

</details>

[Example app](https://github.com/tattn/LocalLLMClient/tree/main/Example)

> [!IMPORTANT]
> This project is still experimental. The API is subject to change.

## Features

- Support for [GGUF](https://github.com/ggml-org/ggml/blob/master/docs/gguf.md) / [MLX models](https://opensource.apple.com/projects/mlx/) / [FoundationModels framework](https://developer.apple.com/documentation/foundationmodels)
- Support for iOS, macOS and Linux
- Streaming API
- Multimodal (experimental)
- Tool calling (experimental)

## Installation

Add the following dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/tattn/LocalLLMClient.git", branch: "main")
]
```

## Usage

The API documentation is available [here](https://tattn.github.io/LocalLLMClient/documentation/).

### Quick Start

```swift
import LocalLLMClient
import LocalLLMClientLlama

let session = LLMSession(model: .llama(
    id: "lmstudio-community/gemma-3-4B-it-qat-GGUF",
    model: "gemma-3-4B-it-QAT-Q4_0.gguf"
))

print(try await session.respond(to: "Tell me a joke."))

for try await text in session.streamResponse(to: "Write a story about cats.") {
    print(text, terminator: "")
}
```

### Using with Each Backend

<details open>
<summary>Using llama.cpp</summary>

```swift
import LocalLLMClient
import LocalLLMClientLlama

// Create a model
let model = LLMSession.DownloadModel.llama(
    id: "lmstudio-community/gemma-3-4B-it-qat-GGUF",
    model: "gemma-3-4B-it-QAT-Q4_0.gguf",
    parameter: .init(
        temperature: 0.7,   // Randomness (0.0〜1.0)
        topK: 40,           // Top-K sampling
        topP: 0.9,          // Top-P (nucleus) sampling
        options: .init(responseFormat: .json) // Response format
    )
)

// You can track download progress
try await model.downloadModel { progress in 
    print("Download progress: \(progress)")
}

// Create a session with the downloaded model
let session = LLMSession(model: model)

// Generate a response with a specific prompt
let response = try await session.respond(to: """
Create the beginning of a synopsis for an epic story with a cat as the main character.
Format it in JSON, as shown below.
{
    "title": "<title>",
    "content": "<content>",
}
""")
print(response)

// You can also add system messages before asking questions
session.messages = [.system("You are a helpful assistant.")]
```
</details>

<details>
<summary>Using Apple MLX</summary>

```swift
import LocalLLMClient
import LocalLLMClientMLX

// Create a model
let model = LLMSession.DownloadModel.mlx(
    id: "mlx-community/Qwen3-1.7B-4bit",
    parameter: .init(
        temperature: 0.7,    // Randomness (0.0 to 1.0)
        topP: 0.9            // Top-P (nucleus) sampling
    )
)

// You can track download progress
try await model.downloadModel { progress in 
    print("Download progress: \(progress)")
}

// Create a session with the downloaded model
let session = LLMSession(model: model)

// Generate text with system and user messages
session.messages = [.system("You are a helpful assistant.")]
let response = try await session.respond(to: "Tell me a story about a cat.")
print(response)
```
</details>

<details>
<summary>Using Apple FoundationModels</summary>

```swift
import LocalLLMClient
import LocalLLMClientFoundationModels

// Available on iOS 26.0+ / macOS 26.0+ and requires Apple Intelligence 
let session = LLMSession(model: .foundationModels(
    // Use system's default model
    model: .default,
    // Configure generation options
    parameter: .init(
        temperature: 0.7,
    )
))

// Generate a response with a specific prompt
let response = try await session.respond(to: "Tell me a short story about a clever fox.")
print(response)
```
</details>

### Tool Calling

LocalLLMClient supports tool calling for integrations with external systems.

> [!IMPORTANT]
> Tool calling is only available with models that support this feature. Each backend has different model compatibility.
> 
> Make sure your chosen model explicitly supports tool calling before using this feature.

<details open>
<summary>Using tool calling</summary>

```swift
import LocalLLMClient
import LocalLLMClientLlama

@Tool("get_weather")
struct GetWeatherTool {
    let description = "Get the current weather in a given location"
    
    @ToolArguments
    struct Arguments {
        @ToolArgument("The city and state, e.g. San Francisco, CA")
        var location: String
        
        @ToolArgument("Temperature unit")
        var unit: Unit?
        
        @ToolArgumentEnum
        enum Unit: String {
            case celsius
            case fahrenheit
        }
    }
    
    func call(arguments: Arguments) async throws -> ToolOutput {
        // In a real implementation, this would call a weather API
        let temp = arguments.unit == .celsius ? "22°C" : "72°F"
        return ToolOutput([
            "location": arguments.location,
            "temperature": temp,
            "condition": "sunny"
        ])
    }
}

// Create the tool
let weatherTool = GetWeatherTool()

// Create a session with a model that supports tool calling and register tools
let session = LLMSession(
    model: .llama(
        id: "Qwen/Qwen2.5-1.5B-Instruct-GGUF",
        model: "qwen2.5-1.5b-instruct-q4_k_m.gguf"
    ),
    tools: [weatherTool]
)

// Ask a question that requires tool use
let response = try await session.respond(to: "What's the weather like in Tokyo?")
print(response)

// The model will automatically call the weather tool and include the result in its response
```
</details>

### Multimodal for Image Processing

LocalLLMClient also supports multimodal models for processing images.

<details open>
<summary>Using with llama.cpp</summary>

```swift
import LocalLLMClient
import LocalLLMClientLlama

// Create a session with a multimodal model
let session = LLMSession(model: .llama(
    id: "ggml-org/gemma-3-4b-it-GGUF",
    model: "gemma-3-4b-it-Q8_0.gguf",
    mmproj: "mmproj-model-f16.gguf"
))

// Ask a question about an image
let response = try await session.respond(
    to: "What's in this image?", 
    attachments: [.image(.init(resource: .yourImage))]
)
print(response)

// You can also stream the response
for try await text in session.streamResponse(
    to: "Describe this image in detail", 
    attachments: [.image(.init(resource: .yourImage))]
) {
    print(text, terminator: "")
}
```
</details>

<details>
<summary>Using with Apple MLX</summary>

```swift
import LocalLLMClient
import LocalLLMClientMLX

// Create a session with a multimodal model
let session = LLMSession(model: .mlx(
    id: "mlx-community/Qwen2.5-VL-3B-Instruct-abliterated-4bit"
))

// Ask a question about an image
let response = try await session.respond(
    to: "What's in this image?", 
    attachments: [.image(.init(resource: .yourImage))]
)
print(response)
```
</details>

<details>
<summary><h3>Advanced Usage: Low Level API</h3></summary>

For more advanced control over model loading and inference, you can use the `LocalLLMClient` APIs directly.

<details>
<summary>Using with llama.cpp</summary>

```swift
import LocalLLMClient
import LocalLLMClientLlama
import LocalLLMClientUtility

// Download model from Hugging Face (Gemma 3)
let ggufName = "gemma-3-4B-it-QAT-Q4_0.gguf"
let downloader = FileDownloader(source: .huggingFace(
    id: "lmstudio-community/gemma-3-4B-it-qat-GGUF",
    globs: [ggufName]
))

try await downloader.download { print("Progress: \($0)") }

// Initialize a client with the downloaded model
let modelURL = downloader.destination.appending(component: ggufName)
let client = try await LocalLLMClient.llama(url: modelURL, parameter: .init(
    context: 4096,      // Context size
    temperature: 0.7,   // Randomness (0.0〜1.0)
    topK: 40,           // Top-K sampling
    topP: 0.9,          // Top-P (nucleus) sampling
    options: .init(responseFormat: .json) // Response format
))

let prompt = """
Create the beginning of a synopsis for an epic story with a cat as the main character.
Format it in JSON, as shown below.
{
    "title": "<title>",
    "content": "<content>",
}
"""

// Generate text
let input = LLMInput.chat([
    .system("You are a helpful assistant."),
    .user(prompt)
])

for try await text in try await client.textStream(from: input) {
    print(text, terminator: "")
}
```
</details>

<details>
<summary>Using with Apple MLX</summary>

```swift
import LocalLLMClient
import LocalLLMClientMLX
import LocalLLMClientUtility

// Download model from Hugging Face
let downloader = FileDownloader(
    source: .huggingFace(id: "mlx-community/Qwen3-1.7B-4bit", globs: .mlx)
)
try await downloader.download { print("Progress: \($0)") }

// Initialize a client with the downloaded model
let client = try await LocalLLMClient.mlx(url: downloader.destination, parameter: .init(
    temperature: 0.7,    // Randomness (0.0 to 1.0)
    topP: 0.9            // Top-P (nucleus) sampling
))

// Generate text
let input = LLMInput.chat([
    .system("You are a helpful assistant."),
    .user("Tell me a story about a cat.")
])

for try await text in try await client.textStream(from: input) {
    print(text, terminator: "")
}
```
</details>

<details>
<summary>Using with Apple FoundationModels</summary>

```swift
import LocalLLMClient
import LocalLLMClientFoundationModels

// Available on iOS 26.0+ / macOS 26.0+ and requires Apple Intelligence 
let client = try await LocalLLMClient.foundationModels(
    // Use system's default model
    model: .default,
    // Configure generation options
    parameter: .init(
        temperature: 0.7,
    )
)

// Generate text
let input = LLMInput.chat([
    .system("You are a helpful assistant."),
    .user("Tell me a short story about a clever fox.")
])

for try await text in try await client.textStream(from: input) {
    print(text, terminator: "")
}
```
</details>

<details>
<summary>Advanced Multimodal with llama.cpp</summary>

```swift
import LocalLLMClient
import LocalLLMClientLlama
import LocalLLMClientUtility

// Download model from Hugging Face (Gemma 3)
let model = "gemma-3-4b-it-Q8_0.gguf"
let mmproj = "mmproj-model-f16.gguf"

let downloader = FileDownloader(
    source: .huggingFace(id: "ggml-org/gemma-3-4b-it-GGUF", globs: [model, mmproj]),
)
try await downloader.download { print("Download: \($0)") }

// Initialize a client with the downloaded model
let client = try await LocalLLMClient.llama(
    url: downloader.destination.appending(component: model),
    mmprojURL: downloader.destination.appending(component: mmproj)
)

let input = LLMInput.chat([
    .user("What's in this image?", attachments: [.image(.init(resource: .yourImage))]),
])

// Generate text without streaming
print(try await client.generateText(from: input))
```
</details>

<details>
<summary>Advanced Multimodal with Apple MLX</summary>

```swift
import LocalLLMClient
import LocalLLMClientMLX
import LocalLLMClientUtility

// Download model from Hugging Face (Qwen2.5 VL)
let downloader = FileDownloader(source: .huggingFace(
    id: "mlx-community/Qwen2.5-VL-3B-Instruct-abliterated-4bit",
    globs: .mlx
))
try await downloader.download { print("Progress: \($0)") }

let client = try await LocalLLMClient.mlx(url: downloader.destination)

let input = LLMInput.chat([
    .user("What's in this image?", attachments: [.image(.init(resource: .yourImage))]),
])

// Generate text without streaming
print(try await client.generateText(from: input))
```
</details>
</details>

### CLI Tool

You can use LocalLLMClient directly from the terminal using the command line tool:

```bash
# Run using llama.cpp
swift run LocalLLMCLI --model /path/to/your/model.gguf "Your prompt here"

# Run using MLX
./scripts/run_mlx.sh --model https://huggingface.co/mlx-community/Qwen3-1.7B-4bit "Your prompt here"
```

## Tested Models

- LLaMA 3
- Gemma 3 / 2
- Qwen 3 / 2
- Phi 4


> [Models compatible with llama.cpp backend](https://github.com/ggml-org/llama.cpp?tab=readme-ov-file#text-only)  
> [Models compatible with MLX backend](https://github.com/ml-explore/mlx-swift-examples/blob/main/Libraries/MLXLLM/Documentation.docc/Documentation.md)  

*If you have a model that works, please open an issue or PR to add it to the list.*

## Requirements

- iOS 16.0+ / macOS 14.0+
- Xcode 16.0+

## Acknowledgements

This package uses [llama.cpp](https://github.com/ggml-org/llama.cpp), [Apple's MLX](https://opensource.apple.com/projects/mlx/) and [Foundation Models framework](https://developer.apple.com/documentation/foundationmodels) for model inference.

---

[Support this project :heart:](https://github.com/sponsors/tattn)
