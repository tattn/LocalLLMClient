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
        let templateContext = buildTemplateContext(
            messages: messagesData,
            tools: tools,
            hasNativeToolSupport: hasNativeToolSupport,
            context: context
        )
        
        // Render template
        do {
            return try jinjaTemplate.render(templateContext)
        } catch {
            throw LLMError.invalidParameter(reason: "Failed to render template: \(error.localizedDescription)")
        }
    }
    
    private func buildTemplateContext(
        messages: [[String: any Sendable]],
        tools: [AnyLLMTool],
        hasNativeToolSupport: Bool,
        context: TemplateContext
    ) -> [String: Any] {
        var templateContext: [String: Any] = [
            "add_generation_prompt": true,
            "messages": messages
        ]
        
        // Add special tokens
        templateContext.merge(context.specialTokens) { _, new in new }
        
        // Add tools for templates with native support
        if !tools.isEmpty && hasNativeToolSupport {
            templateContext["tools"] = tools.compactMap { $0.toOAICompatJSON() }
        }
        
        // Add additional context
        templateContext.merge(context.additionalContext) { _, new in new }
        
        return templateContext
    }
}
