import Foundation
import LlamaSwiftExperimental
import Synchronization

public final class LlamaClient: LLMClient {
    private let context: Mutex<Context>

    public init(url: URL, parameter: LLMParameter = .default) throws {
        context = try .init(Context(url: url, parameter: parameter))
    }

    public func predict(_ input: LLMInput) async throws -> String {
        var finalResult = ""
        for try await token in try predict(input) {
            finalResult += token
#if DEBUG
            print(token)
#endif
        }
        return finalResult
    }

    public func predict(_ input: LLMInput) throws -> Generator {
        try context.withLock { context in
            var decodeContext = DecodingContext(cursor: 0, special: input.parsesSpecial ?? false)
            var promptCursor = input.prompt.startIndex
            var attachments = input.attachments

            do {
                while !attachments.isEmpty {
                    let value = attachments
                        .compactMap { attachment in
                            input.prompt.firstRange(of: attachment.key).map {
                                (attachment: attachment, range: $0)
                            }
                        }
                        .sorted(by: { $0.range.lowerBound < $1.range.lowerBound })
                        .first

                    guard let value else {
                        assertionFailure("Attachment's key is not found in prompt")
                        break
                    }

                    if promptCursor < value.range.lowerBound {
                        let text = String(input.prompt[promptCursor..<value.range.lowerBound])
                        decodeContext = try context.decode(text: text, context: decodeContext)
                    }

                    switch value.attachment.value {
                    case let .text(text):
                        decodeContext = try context.decode(text: text, context: decodeContext)
                    case let .image(embedding):
                        if let embed = embedding as? ImageEmbed {
                            decodeContext = try context.decode(imageEmbed: embed, context: decodeContext)
                        } else {
                            assertionFailure("Implementation error: image's embedding is not ImageEmbed")
                        }
                    }

                    promptCursor = value.range.upperBound
                    attachments.removeValue(forKey: value.attachment.key)
                }

                let text = String(input.prompt[promptCursor...])
                decodeContext = try context.decode(text: text, context: decodeContext)
            } catch {
                throw LLMError.decodingFailed
            }

            return Generator(context: context, decodeContext: decodeContext)
        }
    }
}
