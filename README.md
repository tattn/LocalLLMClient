# LocalLLMClient

![logo](https://github.com/user-attachments/assets/3975c03a-cb1a-474f-94a1-726fd2de93b2)

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/tattn/LocalLLMClient/actions/workflows/test.yml/badge.svg)](https://github.com/tattn/LocalLLMClient/actions/workflows/test.yml)

A Swift package to interact with local Large Language Models (LLMs) on Apple platforms.

> [!IMPORTANT]
> This project is still experimental. The API is subject to change.

## Features

- Support for GGUF model format
- Support for iOS and macOS
- Configurable parameters for inference (temperature, top-k, top-p, etc.)
- Streaming token generation
- Command-line interface

## Installation

Add the following dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/tattn/LocalLLMClient.git", branch: "main")
]
```

## Usage

### Basic Example

```swift
import LocalLLMClient

// Download a model file
let remoteURL = URL(string: "https://huggingface.co/unsloth/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q5_K_M.gguf")!
let (modelURL, _) = try await URLSession.shared.download(from: remoteURL)

// Initialize a client with the path to your model file
let client = try LocalLLMClient.makeClient(url: modelURL)

// Generate text
let prompt = "1 + 2 = ?"
let text = try await client.predict(prompt)
print(text)
```

### Streaming Example

The client provides an async sequence API for accessing tokens as they're generated:

```swift
import LocalLLMClient

// Initialize a client with the path to your model file
let modelURL = URL(fileURLWithPath: "path/to/your/model.gguf")
let client = try LocalLLMClient.makeClient(url: modelURL)

// Process tokens as they arrive in real-time
let prompt = "Tell me a story about a cat"
for try await token in client.predict(prompt) {
    print(token, terminator: "")
}
```

### Custom Parameters

You can customize the LLM parameters when initializing the context:

```swift
import LocalLLMClient

// Configure custom parameters
let params = LLMParameter(
    context: 4096,             // Text context size (0 = size the model was trained on)
    numberOfThreads: 4,        // CPU threads to use (nil = auto)
    temperature: 0.7,          // Randomness (0.0 to 1.0)
    topK: 40,                  // Top-K sampling
    topP: 0.9,                 // Top-P (nucleus) sampling
)

let modelURL = URL(fileURLWithPath: "path/to/your/model.gguf")
let client = try LocalLLMClient.makeClient(url: modelURL, parameter: params)

// Generate text
let prompt = "Write a poem about a cat"
let text = try await client.predict(prompt)
print(text)
```

### CLI tool

You can use LocalLLMClient directly from the terminal using the command line tool:

```bash
swift run localllm --model path/to/your/model.gguf "Your prompt here"
```

## Tested models

- LLaMA 3
- Gemma 3 / 2

[*Most text models supported by llama.cpp can work.*](https://github.com/ggml-org/llama.cpp?tab=readme-ov-file#text-only)  
*If you have a model that works, please open an issue or PR to add it to the list.*

## Requirements

- iOS 16.0+ / macOS 13.0+
- Xcode 16.3+

## Acknowledgements

This package uses [llama.cpp](https://github.com/ggml-org/llama.cpp).

---

[Support this project :heart:](https://github.com/sponsors/tattn)