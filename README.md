# LocalLLMClient

A Swift package to interact with local Large Language Models (LLMs) on Apple platforms.

> [!IMPORTANT]
> This project is still experimental. The API is subject to change.

## Features

- Support for GGUF model format
- Async/await support for non-blocking text generation
- Streaming token generation
- Configurable parameters for inference (temperature, top-k, top-p, etc.)
- Support for iOS and macOS

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

The generator provides an async sequence API for accessing tokens as they're generated:

```swift
import LocalLLMClient
import LlamaSwift

// Initialize the context and generator directly
let modelURL = URL(fileURLWithPath: "path/to/your/model.gguf")
let context = try Context(url: modelURL)
let generator = Generator(text: "Tell me a story about a cat", context: context)

// Process tokens as they arrive
for try await token in generator {
    print(token, terminator: "")
}
```

### Custom Parameters

You can customize the LLM parameters when initializing the context:

```swift
import LocalLLMClient
import LlamaSwift

let modelURL = URL(fileURLWithPath: "path/to/your/model.gguf")

// Configure custom parameters
let params = LLMParameter(
    context: 4096,             // Text context size (0 = size the model was trained on)
    numberOfThreads: 4,        // CPU threads to use (nil = auto)
    temperature: 0.7,          // Randomness (0.0 to 1.0)
    topK: 40,                  // Top-K sampling
    topP: 0.9,                 // Top-P (nucleus) sampling
)

let context = try Context(url: modelURL, parameter: params)
let generator = Generator(text: "Write a poem about a cat", context: context)

for try await token in generator {
    print(token, terminator: "")
}
```

## Tested models

- LLaMA 3
- Gemma 3 / 2

*If you have a model that works, please open an issue or PR to add it to the list.*

## Requirements

- iOS 16.0+ / macOS 13.0+
- Xcode 16.3+

## Acknowledgements

This package uses [llama.cpp](https://github.com/ggml-org/llama.cpp).

---

[Support this project :heart:](https://github.com/sponsors/tattn)