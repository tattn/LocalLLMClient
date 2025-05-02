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
        for try await token in predict(input) {
            finalResult += token
#if DEBUG
            print(token)
#endif
        }
        return finalResult
    }

    public func predict(_ input: LLMInput) -> Generator {
        context.withLock { context in
            let special = input.parsesSpecial ?? false
            var cursor: Int32 = 0
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
                        cursor = try context.decode(text: text, cursor: cursor, special: special)
                    }

                    switch value.attachment.value {
                    case let .text(text):
                        cursor = try context.decode(text: text, cursor: cursor, special: special)
                    case let .image(embedding):
                        if let embed = embedding as? ImageEmbed {
                            cursor = try context.decode(imageEmbed: embed, cursor: cursor)
                        } else {
                            assertionFailure("Implementation error: image's embedding is not ImageEmbed")
                        }
                    }

                    promptCursor = value.range.upperBound
                    attachments.removeValue(forKey: value.attachment.key)
                }

                let text = String(input.prompt[promptCursor...])
                cursor = try context.decode(text: text, cursor: cursor, special: special)
            } catch {
                // TODO: handle error
            }

            return Generator(context: context, cursor: cursor, special: special)
        }
    }
}
