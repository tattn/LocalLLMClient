import Testing
import Foundation
@testable import LocalLLMClient

@Test func simple() async throws {
    let url = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LOCAL_LLM_PATH"]!)
    let client = try LocalLLMClient.makeClient(url: url)
    let input = "What is the answer to one plus two?"

    let result = try await client.predict(input)
    print(result)

    #expect(!result.isEmpty)
}
