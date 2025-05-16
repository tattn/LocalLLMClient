# LocalLLMClient

![logo](https://github.com/user-attachments/assets/3975c03a-cb1a-474f-94a1-726fd2de93b2)

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/tattn/LocalLLMClient/actions/workflows/test.yml/badge.svg)](https://github.com/tattn/LocalLLMClient/actions/workflows/test.yml)

A Swift package to interact with local Large Language Models (LLMs) on Apple platforms.

| MobileVLM-3B (llama.cpp) | Qwen2.5 VL 3B (MLX) |
|:-:|:-:|
|<video src="https://github.com/user-attachments/assets/7704b05c-2a8c-40ef-838c-f9485ad0cfe0">|<video src="https://github.com/user-attachments/assets/475609a4-aaef-4043-aadc-db44c28296ee">|

*iPhone 16 Pro*

[Example app](https://github.com/tattn/LocalLLMClient/tree/main/Example)

> [!IMPORTANT]
> This project is still experimental. The API is subject to change.

## Features

- Support for GGUF / MLX models
- Support for iOS and macOS
- Streaming API
- Multimodal (experimental)

## Installation

Add the following dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/tattn/LocalLLMClient.git", branch: "main")
]
```

## Usage

The API documentation is available [here](https://tattn.github.io/LocalLLMClient/documentation/).

### Basic Usage

<details open>
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

### Multimodal for Image

LocalLLMClient supports multimodal models like LLaVA for processing images along with text prompts.

<details open>
<summary>Using with llama.cpp</summary>

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
<summary>Using with Apple MLX</summary>

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

### Utility

- `FileDownloader`: A utility to download models with progress tracking.
- `BackgroundFileDownloader`: A utility to download models in the background for iOS apps.

### CLI tool

You can use LocalLLMClient directly from the terminal using the command line tool:

```bash
# Run using llama.cpp
swift run localllm --model /path/to/your/model.gguf "Your prompt here"

# Run using MLX
./scripts/run_mlx.sh --model https://huggingface.co/mlx-community/Qwen3-1.7B-4bit "Your prompt here"
```

## Tested models

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

This package uses [llama.cpp](https://github.com/ggml-org/llama.cpp) and [Apple's MLX](https://opensource.apple.com/projects/mlx/) for model inference.

---

[Support this project :heart:](https://github.com/sponsors/tattn)
