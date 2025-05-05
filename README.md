# LocalLLMClient

![logo](https://github.com/user-attachments/assets/3975c03a-cb1a-474f-94a1-726fd2de93b2)

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/tattn/LocalLLMClient/actions/workflows/test.yml/badge.svg)](https://github.com/tattn/LocalLLMClient/actions/workflows/test.yml)

A Swift package to interact with local Large Language Models (LLMs) on Apple platforms.

| MobileVLM-3B (llama.cpp) | Qwen2.5 VL 3B (MLX) |
|:-:|:-:|
|<video src="https://github.com/user-attachments/assets/7704b05c-2a8c-40ef-838c-f9485ad0cfe0">|<video src="https://github.com/user-attachments/assets/475609a4-aaef-4043-aadc-db44c28296ee">|

*iPhone 16 Pro*


> [!IMPORTANT]
> This project is still experimental. The API is subject to change.

## Features

- Support for GGUF / MLX models
- Support for iOS and macOS
- Configurable parameters: temperature, top-k, top-p, etc.
- Streaming API
- Command-line interface
- Multimodal (experimental)

## Installation

Add the following dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/tattn/LocalLLMClient.git", branch: "main")
]
```

## Usage

### Basic Example

<details open>
<summary>Using with llama.cpp</summary>

```swift
import LocalLLMClient
import LocalLLMClientLlama

// Download a model file
let remoteURL = URL(string: "https://huggingface.co/unsloth/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q5_K_M.gguf")!
let (modelURL, _) = try await URLSession.shared.download(from: remoteURL)

// Initialize a client with the path to your model file
let client = try LocalLLMClient.llama(url: modelURL)

// Generate text
let prompt = "Tell me a story about a cat"
let text = try await client.generateText(from: prompt)
print(text)
```

```swift
// Streaming text
for try await text in try client.textStream(from: prompt) {
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
</details>

### Custom Parameters

<details open>
<summary>Using with llama.cpp</summary>

```swift
import LocalLLMClient
import LocalLLMClientLlama

// Configure custom parameters
let modelURL = URL(fileURLWithPath: "path/to/your/model.gguf")
let client = try LocalLLMClient.llama(url: modelURL, parameter: .init(
    context: 4096,       // Text context size (0 = size the model was trained on)
    numberOfThreads: 4,  // CPU threads to use (nil = auto)
    temperature: 0.7,    // Randomness (0.0 to 1.0)
    topK: 40,            // Top-K sampling
    topP: 0.9,           // Top-P (nucleus) sampling
))

// Generate text
let prompt = "Write a poem about a cat"
let text = try await client.generateText(from: prompt)
print(text)
```
</details>

<details>
<summary>Using with Apple MLX</summary>

```swift
import LocalLLMClient
import LocalLLMClientMLX

// Configure custom parameters
let modelURL = URL(fileURLWithPath: "path/to/your/mlx-model")
let client = try await LocalLLMClient.mlx(url: modelURL, parameter: .init(
    temperature: 0.7,          // Randomness (0.0 to 1.0)
    topP: 0.9                  // Top-P (nucleus) sampling
))

// Generate text
let prompt = "Write a poem about a cat"
let text = try await client.generateText(from: prompt)
print(text)
```
</details>

### CLI tool

You can use LocalLLMClient directly from the terminal using the command line tool:

```bash
swift run localllm --model /path/to/your/model.gguf "Your prompt here"
swift run localllm --model "https://huggingface.co/mlx-community/Qwen3-1.7B-4bit" --backend mlx "Your prompt here"
```

## Multimodal for Image (Experimental)

LocalLLMClient supports multimodal models like LLaVA for processing images along with text prompts. To use this feature:

<details open>
<summary>Using with llama.cpp</summary>

```swift
import LocalLLMClient
import LocalLLMClientLlama

// Download model from Hugging Face
let model = "gemma-3-4b-it-Q8_0.gguf"
let clip = "mmproj-model-f16.gguf"

let downloader = FileDownloader(
    source: .huggingFace(id: "ggml-org/gemma-3-4b-it-GGUF", globs: [model, clip]),
)
let url = try await downloader.download { print("Download: \($0)") }

let client = try LocalLLMClient.llama(
    url: url.appending(component: model),
    clipURL: url.appending(component: clip)
)

let input = LLMInput(
    prompt: "<start_of_turn>user\nWhat's in this image?<end_of_turn>\n<start_of_turn>assistant\n",
    attachments: [.image(.init(resource: .yourImage))],
    parameters: .init(tokenImageStart: "<start_of_image>", tokenImageEnd: "<end_of_image>")
)

for try await text in client.textStream(from: input) {
    print(text, terminator: "")
}
```
</details>

<details>
<summary>Using with Apple MLX</summary>

```swift
import LocalLLMClient
import LocalLLMClientMLX

// Download model from Hugging Face
let downloader = FileDownloader(
    source: .huggingFace(id: "mlx-community/Qwen2-VL-2B-Instruct-4bit", globs: .mlx)
)
let modelURL = try await downloader.download { print("Progress: \($0)") }

let client = try await LocalLLMClient.mlx(url: modelURL)

let input = LLMInput(
    prompt: "What can you see in this image?",
    attachments: [.image(.init(resource: .yourImage))]
)

for try await text in try await client.textStream(from: input) {
    print(text, terminator: "")
}
```
</details>

When using multimodal models, you'll need:
1. A GGUF format LLM that supports multimodal inputs (like LLaVA, Gemma 3, etc.)
    1. Try [gemma-3-4b-it-GGUF](https://huggingface.co/ggml-org/gemma-3-4b-it-GGUF/tree/main) (Q8_0) or [Qwen2-VL-2B-Instruct](https://huggingface.co/mlx-community/Qwen2-VL-2B-Instruct-4bit/tree/main)
2. A matching CLIP projection model (.gguf format)
3. The image you want to analyze

Supported image formats include JPEG, PNG, and other common formats.

## Tested models

- LLaMA 3
- Gemma 3 / 2
- Qwen 3 / 2


> [Models compatible with llama.cpp backend](https://github.com/ggml-org/llama.cpp?tab=readme-ov-file#text-only)  
> [Models compatible with MLX backend](https://github.com/ml-explore/mlx-swift-examples/blob/main/Libraries/MLXLLM/Documentation.docc/Documentation.md)  

*If you have a model that works, please open an issue or PR to add it to the list.*

## Requirements

- iOS 18.0+ / macOS 15.0+
- Xcode 16.3+

## Acknowledgements

This package uses [llama.cpp](https://github.com/ggml-org/llama.cpp) and [Apple's MLX](https://opensource.apple.com/projects/mlx/) for model inference.

---

[Support this project :heart:](https://github.com/sponsors/tattn)
