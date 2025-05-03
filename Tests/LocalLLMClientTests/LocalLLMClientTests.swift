import Testing
import Foundation
import LocalLLMClient
import LlamaSwift

private let url = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LOCAL_LLM_PATH"]!)

@Test func simple() async throws {
    let client = try LocalLLMClient.llama(url: url)
    let input = "What is the answer to one plus two?"

    let result = try await client.predict(input)
    print(result)

    #expect(!result.isEmpty)
}

@Test func simpleStream() async throws {
    let client = try LocalLLMClient.llama(url: url)
    let input = "What is the answer to one plus two?"

    var result = ""
    for try await text in try client.predict(input) {
        print(text)
        result += text
    }

    #expect(!result.isEmpty)
}
