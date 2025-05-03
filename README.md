# LocalLLMClient

![logo](https://github.com/user-attachments/assets/3975c03a-cb1a-474f-94a1-726fd2de93b2)

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/tattn/LocalLLMClient/actions/workflows/test.yml/badge.svg)](https://github.com/tattn/LocalLLMClient/actions/workflows/test.yml)

A Swift package to interact with local Large Language Models (LLMs) on Apple platforms.

https://github.com/user-attachments/assets/478d5c58-19e4-4c33-8ad2-53ec511a86e8

*This video shows a multimodal LLM running on iPhone 16 Pro at natural, real-time speed (MobileVLM-3B)*

> [!IMPORTANT]
> This project is still experimental. The API is subject to change.

## Features

- Support for GGUF / MLX models
- Support for iOS and macOS
- Configurable parameters for inference (temperature, top-k, top-p, etc.)
- Streaming token generation
- Command-line interface
- Multimodal models (experimental)

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
<summary>Using with llama.cpp (LocalLLMClientLlama)</summary>

```swift
import LocalLLMClient
import LocalLLMClientLlama

// Download a model file
let remoteURL = URL(string: "https://huggingface.co/unsloth/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q5_K_M.gguf")!
let (modelURL, _) = try await URLSession.shared.download(from: remoteURL)

// Initialize a client with the path to your model file
let client = try LocalLLMClient.llama(url: modelURL)

// Generate text
let prompt = "1 + 2 = ?"
let text = try await client.generateText(from: prompt)
print(text)
```
</details>

<details>
<summary>Using with Apple MLX (LocalLLMClientMLX)</summary>

```swift
import LocalLLMClient
import LocalLLMClientMLX

// Initialize a client with the path to your model
let modelURL = URL(fileURLWithPath: "path/to/your/mlx-model")
let client = try await LocalLLMClient.mlx(url: modelURL)

// Generate text
let prompt = "1 + 2 = ?"
let text = try await client.generateText(from: prompt)
print(text)
```
</details>

### Streaming Example

<details open>
<summary>Using with llama.cpp (LocalLLMClientLlama)</summary>

```swift
import LocalLLMClient
import LocalLLMClientLlama

// Initialize a client with the path to your model file
let modelURL = URL(fileURLWithPath: "path/to/your/model.gguf")
let client = try LocalLLMClient.llama(url: modelURL)

// Process tokens as they arrive in real-time
let prompt = "Tell me a story about a cat"
for try await token in try client.textStream(from: prompt) {
    print(token, terminator: "")
}
```
</details>

<details>
<summary>Using with Apple MLX (LocalLLMClientMLX)</summary>

```swift
import LocalLLMClient
import LocalLLMClientMLX

// Initialize a client with the path to your model
let modelURL = URL(fileURLWithPath: "path/to/your/mlx-model")
let client = try await LocalLLMClient.mlx(url: modelURL)

// Process tokens as they arrive in real-time
let prompt = "Tell me a story about a cat"
for try await token in try await client.textStream(from: prompt) {
    print(token, terminator: "")
}
```
</details>

### Custom Parameters

<details open>
<summary>Using with llama.cpp (LocalLLMClientLlama)</summary>

```swift
import LocalLLMClient
import LocalLLMClientLlama

// Configure custom parameters
let modelURL = URL(fileURLWithPath: "path/to/your/model.gguf")
let client = try LocalLLMClient.llama(url: modelURL, parameter: .init(
    context: 4096,             // Text context size (0 = size the model was trained on)
    numberOfThreads: 4,        // CPU threads to use (nil = auto)
    temperature: 0.7,          // Randomness (0.0 to 1.0)
    topK: 40,                  // Top-K sampling
    topP: 0.9,                 // Top-P (nucleus) sampling
))

// Generate text
let prompt = "Write a poem about a cat"
let text = try await client.generateText(from: prompt)
print(text)
```
</details>

<details>
<summary>Using with Apple MLX (LocalLLMClientMLX)</summary>

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

```swift
import LocalLLMClient
import LocalLLMClientLlama

let clipURL = URL(filePath: "path/to/mmproj-model-f16.gguf")
let modelURL = URL(filePath: "path/to/multimodal-model.gguf")
let imageURL = URL(filePath: "path/to/your/image.jpeg")

// Load the CLIP model for image embedding
let clipModel = try ClipModel(url: clipURL)

// Generate image embedding
let embed = try clipModel.embedded(imageData: Data(contentsOf: imageURL))

let client = try LocalLLMClient.llama(url: modelURL)

let input = LLMInput(
    prompt: "<start_of_image><$IMG$><end_of_image><start_of_turn>user\nWhat's in this image?<end_of_turn>\n<start_of_turn>assistant\n",
    parsesSpecial: true,
    attachments: [
        "<$IMG$>": .image(embed),
    ]
)

for try await token in client.textStream(from: input) {
    print(token, terminator: "")
}
```

When using multimodal models, you'll need:
1. A GGUF format LLM that supports multimodal inputs (like LLaVA, Gemma 3, etc.)
    1. Try [gemma-3-4b-it-GGUF](https://huggingface.co/ggml-org/gemma-3-4b-it-GGUF/tree/main) (Q8_0)
2. A matching CLIP projection model (.gguf format)
3. The image you want to analyze

Supported image formats include JPEG, PNG, and other common formats.

## Tested models

- LLaMA 3
- Gemma 3 / 2

[*Most text models supported by llama.cpp can work.*](https://github.com/ggml-org/llama.cpp?tab=readme-ov-file#text-only)  
*If you have a model that works, please open an issue or PR to add it to the list.*

## Requirements

- iOS 16.0+ / macOS 13.0+
- Xcode 16.3+

## Acknowledgements

This package uses [llama.cpp](https://github.com/ggml-org/llama.cpp) and [Apple's MLX](https://opensource.apple.com/projects/mlx/) for model inference.

---

[Support this project :heart:](https://github.com/sponsors/tattn)
