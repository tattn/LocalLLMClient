import Foundation
import LocalLLMClientUtility
import RegexBuilder

/// Processes streaming text to detect and extract tool calls
package final class StreamingToolCallProcessor: Sendable {
    
    // All mutable state encapsulated in a struct
    private struct ProcessorState: Sendable {
        var state = State.normal
        var buffer = ""
        var toolCalls: [LLMToolCall] = []
    }
    
    private let processorState = Locked(ProcessorState())
    
    // Track the current state of processing
    private enum State {
        case normal
        case potentialToolCall
        case collectingToolCall
    }
    
    // Tags to detect - these may vary by chat format
    private let startTag: String
    private let endTag: String
    
    /// Initialize with specific tags for tool call detection
    /// - Parameters:
    ///   - startTag: The opening tag for tool calls (default: "<tool_call>")
    ///   - endTag: The closing tag for tool calls (default: "</tool_call>")
    package init(startTag: String = "<tool_call>", endTag: String = "</tool_call>") {
        self.startTag = startTag
        self.endTag = endTag
    }
    
    /// The currently collected tool calls
    package var toolCalls: [LLMToolCall] {
        processorState.withLock { $0.toolCalls }
    }
    
    /// Process a chunk of streaming text
    /// - Parameter chunk: The text chunk to process
    /// - Returns: Any regular text that should be yielded (non-tool call content)
    package func processChunk(_ chunk: String) -> String? {
        processorState.withLock {
            processChunkInternal(chunk, state: &$0)
        }
    }
    
    private func processChunkInternal(_ chunk: String, state: inout ProcessorState) -> String? {
        guard (state.state == .normal && chunk.contains("<")) || state.state != .normal else {
            return chunk
        }
        
        state.buffer += chunk
        var leadingText: String?
        
        switch state.state {
        case .normal:
            // Check if this might be the start of a tool call
            state.state = .potentialToolCall
            leadingText = separateText(from: &state.buffer, separator: "<", returnLeading: true)
            fallthrough
            
        case .potentialToolCall:
            if partialMatch(buffer: state.buffer, tag: startTag) {
                if state.buffer.starts(with: startTag) {
                    state.state = .collectingToolCall
                    return leadingText
                } else {
                    return nil
                }
            } else {
                // Not a tool call, return the collected text
                state.state = .normal
                let text = state.buffer
                state.buffer = ""
                return (leadingText ?? "") + text
            }
            
        case .collectingToolCall:
            if state.buffer.contains(endTag) {
                // Extract the tool call content
                let trailingText = separateText(from: &state.buffer, separator: endTag, returnLeading: false)
                
                // Parse the tool call
                if let toolCall = parseToolCall(from: state.buffer) {
                    state.toolCalls.append(toolCall)
                }
                
                state.state = .normal
                state.buffer = ""
                
                // Process any remaining text
                if let trailingText, trailingText.contains("<") {
                    return processChunkInternal(trailingText, state: &state)
                } else {
                    return trailingText?.isEmpty ?? true ? nil : trailingText
                }
            } else {
                return nil
            }
        }
    }
    
    /// Reset the processor state
    package func reset() {
        processorState.withLock {
            $0 = ProcessorState()
        }
    }
    
    // MARK: - Private helpers
    
    private func separateText(from buffer: inout String, separator: String, returnLeading: Bool) -> String? {
        guard let range = buffer.range(of: separator) else { return nil }
        
        let text: String
        if returnLeading {
            text = String(buffer[..<range.lowerBound])
            buffer = String(buffer[range.lowerBound...])
        } else {
            text = String(buffer[range.upperBound...])
            buffer = String(buffer[..<range.upperBound])
        }
        
        return text
    }
    
    private func partialMatch(buffer: String, tag: String) -> Bool {
        for (tagIndex, bufferIndex) in zip(tag.indices, buffer.indices) {
            if buffer[bufferIndex] != tag[tagIndex] {
                return false
            }
        }
        return true
    }
    
    private func parseToolCall(from content: String) -> LLMToolCall? {
        // Define regex to match: startTag + whitespace + JSON content + whitespace + endTag
        let regex = Regex {
            startTag
            ZeroOrMore(.whitespace)
            Capture {
                OneOrMore(.any, .reluctant)
            }
            ZeroOrMore(.whitespace)
            endTag
        }
        .dotMatchesNewlines()
        
        guard let match = content.firstMatch(of: regex) else {
            return nil
        }
        
        let jsonString = String(match.output.1)
        
        // Try to parse as JSON
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String else {
            return nil
        }
        
        // Extract arguments
        let arguments: String
        if let args = json["arguments"] {
            if let argsData = try? JSONSerialization.data(withJSONObject: args) {
                arguments = String(decoding: argsData, as: UTF8.self)
            } else {
                arguments = "{}"
            }
        } else {
            arguments = "{}"
        }
        
        let id = (json["id"] as? String) ?? UUID().uuidString
        
        return LLMToolCall(id: id, name: name, arguments: arguments)
    }
}