import LocalLLMClientCore
import Foundation
import Jinja

/// Context for template rendering
struct TemplateContext {
    let specialTokens: [String: String]
    let additionalContext: [String: Any]

    init(
        specialTokens: [String: String] = [:],
        additionalContext: [String: Any] = [:]
    ) {
        self.specialTokens = specialTokens
        self.additionalContext = additionalContext
    }
}

/// Protocol for rendering chat templates
 protocol ChatTemplateRenderer: Sendable {
    /// Render messages using a chat template
    func render(
        messages: [LLMInput.ChatTemplateMessage],
        template: String,
        context: TemplateContext,
        tools: [AnyLLMTool]
    ) throws(LLMError) -> String
}

/// Standard Jinja-based template renderer
 struct JinjaChatTemplateRenderer: ChatTemplateRenderer {
    private let toolProcessor: ToolInstructionProcessor

     init(toolProcessor: ToolInstructionProcessor = StandardToolInstructionProcessor()) {
        self.toolProcessor = toolProcessor
    }

     func render(
        messages: [LLMInput.ChatTemplateMessage],
        template: String,
        context: TemplateContext,
        tools: [AnyLLMTool]
    ) throws(LLMError) -> String {
        let jinjaTemplate: Template
        do {
            jinjaTemplate = try Template(template)
        } catch {
            throw LLMError.invalidParameter(reason: "Failed to parse template: \(error.localizedDescription)")
        }

        // Extract message data
        var messagesData = messages.map(\.value)

        // Process tool instructions if needed
        let hasNativeToolSupport = toolProcessor.hasNativeToolSupport(in: template)
        messagesData = try toolProcessor.processMessages(
            messagesData,
            tools: tools,
            templateHasNativeSupport: hasNativeToolSupport
        )

        // Build template context
        let templateContext = try buildTemplateContext(
            messages: messagesData,
            tools: tools,
            hasNativeToolSupport: hasNativeToolSupport,
            context: context
        )

        // Render template
        do {
            let environment = Environment()
            environment.lstripBlocks = true
            environment.trimBlocks = true
            return try jinjaTemplate.render(templateContext, environment: environment)
        } catch {
            throw LLMError.invalidParameter(reason: "Failed to render template: \(error.localizedDescription)")
        }
    }

    private func buildTemplateContext(
        messages: [[String: any Sendable]],
        tools: [AnyLLMTool],
        hasNativeToolSupport: Bool,
        context: TemplateContext
    ) throws(LLMError) -> [String: Value] {
        do {
            var templateContext: [String: Value] = [
                "add_generation_prompt": .boolean(true),
                "messages": try Value(any: messages)
            ]

            // Add special tokens
            try templateContext.merge(context.specialTokens.mapValues { try Value(any: $0) }) { _, new in new }

            // Add tools for templates with native support
            if !tools.isEmpty && hasNativeToolSupport {
                templateContext["tools"] = try Value(any: tools.compactMap { $0.toOAICompatJSON() })
            }

            // Add additional context
            templateContext.merge(try context.additionalContext.mapValues { try Value(any: $0) }) { _, new in new }

            return templateContext
        } catch {
            throw LLMError.invalidParameter(reason: "Failed to build template context: \(error.localizedDescription)")
        }
    }
}
