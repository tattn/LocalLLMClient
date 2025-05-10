import LocalLLMClient

extension [LLMInput.Input.Message] {
    func makeTemplate() throws -> [[String: any Sendable]] {
        map { message in
            [
                "role": message.role.rawValue,
                "content": message.content,
                "type": "text",
            ]
        }
    }
}
