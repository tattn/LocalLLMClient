import Testing
import Foundation
import LocalLLMClientCore
import LocalLLMClientMacros

/// Test infrastructure protocol for tool calling tests
/// Provides common test utilities and test cases that can be used across different LLM client implementations
public protocol ToolTestsProtocol {
    associatedtype ClientType: LLMClient
    
    /// Creates a client instance with the given tools
    func createClient(with tools: [AnyLLMTool]) -> ClientType
    
    // Test method signatures that implementations must provide
    func testBasicToolCalling() async throws
    func testNoToolCallsRequired() async throws
    func testMultipleToolsAvailable() async throws
    func testArrayParameterSupport() async throws
    func testNestedObjectSupport() async throws
    func testToolExecutionError() async throws
    func testInvalidToolArguments() async throws
    func testMultipleToolCallsInSequence() async throws
    func testToolWithOptionalParameters() async throws
    func testSystemPromptWithToolGuidance() async throws
    func testToolCallWithMissingRequiredParameter() async throws
    func testToolCallWithExtraParameters() async throws
    func testToolCallWithWrongTypes() async throws
    func testConcurrentToolExecution() async throws
    func testLargeToolOutput() async throws
    func testToolWithComplexTypes() async throws
    func testToolSchemaGeneration() async throws
    func testToolArgumentMacro() async throws
    func testPerformanceBasicToolCall() async throws
    func testPerformanceComplexArguments() async throws
    func testPerformanceMultipleTools() async throws
}

// MARK: - Test Tool Definitions

/// Test tool for weather queries
@Tool("get_weather")
public struct WeatherTool {
    public let description = "Get the current weather for a location"
    
    @ToolArguments
    public struct Arguments {
        @ToolArgument("The city to get weather for")
        var location: String
        
        @ToolArgument("Temperature unit")
        var unit: Unit?
        
        @ToolArgumentEnum
        public enum Unit: String {
            case celsius
            case fahrenheit
        }
    }
    
    public init() {}
    
    public func call(arguments: Arguments) async throws -> ToolOutput {
        // Mock weather data
        let temp = arguments.unit == .fahrenheit ? 72 : 22
        return ToolOutput(data: [
            "location": arguments.location,
            "temperature": temp,
            "unit": arguments.unit?.rawValue ?? "celsius",
            "conditions": "sunny"
        ])
    }
}

/// Test tool for calculations
@Tool("calculate")
public struct CalculatorTool {
    public let description = "Perform basic arithmetic calculations"
    
    @ToolArguments
    public struct Arguments {
        @ToolArgument("The mathematical expression to evaluate")
        var expression: String
    }
    
    public init() {}
    
    public func call(arguments: Arguments) async throws -> ToolOutput {
        // Simple mock implementation
        let result: Double
        switch arguments.expression {
        case "2 + 2":
            result = 4
        case "10 * 5":
            result = 50
        case "100 / 4":
            result = 25
        default:
            result = 0
        }
        
        return ToolOutput(data: [
            "expression": arguments.expression,
            "result": result
        ])
    }
}

/// Test tool that always throws an error
@Tool("error_tool")
public struct ErrorTool {
    public let description = "A tool that always throws an error"
    
    @ToolArguments
    public struct Arguments {
        @ToolArgument("Any message")
        var message: String
    }
    
    public init() {}
    
    public func call(arguments: Arguments) async throws -> ToolOutput {
        struct TestError: Error, LocalizedError {
            let errorDescription: String?
        }
        throw ToolError.executionFailed(toolName: name, underlyingError: TestError(errorDescription: "This tool always fails"))
    }
}

/// Test tool with array parameters
@Tool("process_items")
public struct ArrayTool {
    public let description = "Process a list of items"
    
    @ToolArguments
    public struct Arguments {
        @ToolArgument("List of items to process")
        var items: [String]
        
        @ToolArgument("Optional tags")
        var tags: [String]?
    }
    
    public init() {}
    
    public func call(arguments: Arguments) async throws -> ToolOutput {
        return ToolOutput(data: [
            "processed_count": arguments.items.count,
            "items": arguments.items,
            "tags": arguments.tags ?? []
        ])
    }
}

/// Test tool with nested objects
@Tool("create_user")
public struct NestedObjectTool {
    public let description = "Create a user with nested information"
    
    @ToolArguments
    public struct Arguments {
        @ToolArgument("User information")
        var user: UserInfo
        
        @ToolArgument("Optional metadata")
        var metadata: [String: String]?
        
        @ToolArguments
        struct UserInfo {
            @ToolArgument("User's name")
            var name: String
            
            @ToolArgument("User's email")
            var email: String
            
            @ToolArgument("User's age")
            var age: Int?
        }
    }
    
    public init() {}
    
    public func call(arguments: Arguments) async throws -> ToolOutput {
        return ToolOutput(data: [
            "created": true,
            "user": [
                "name": arguments.user.name,
                "email": arguments.user.email,
                "age": arguments.user.age ?? 0
            ] as [String: any Sendable]
        ])
    }
}

/// Test tool with optional parameters
@Tool("search")
public struct OptionalParamTool {
    public let description = "Search with optional filters"
    
    @ToolArguments
    public struct Arguments {
        @ToolArgument("Search query")
        var query: String
        
        @ToolArgument("Maximum results")
        var limit: Int?
        
        @ToolArgument("Filter by category")
        var category: String?
        
        @ToolArgument("Sort order")
        var sortOrder: String?
    }
    
    public init() {}
    
    public func call(arguments: Arguments) async throws -> ToolOutput {
        return ToolOutput(data: [
            "query": arguments.query,
            "limit": arguments.limit ?? 10,
            "category": arguments.category ?? "all",
            "sortOrder": arguments.sortOrder ?? "relevance",
            "results": [] as [any Sendable]
        ])
    }
}

/// Test tool with complex types
@Tool("complex_operation")
public struct ComplexTypeTool {
    public let description = "Tool with various complex argument types"
    
    @ToolArguments
    public struct Arguments {
        @ToolArgument("Binary data")
        var data: Data
        
        @ToolArgument("List of numbers")
        var numbers: [Double]
        
        @ToolArgument("Status", enum: ["active", "inactive", "pending"])
        var status: String
        
        @ToolArgument("Nested configuration")
        var config: Config
        
        @ToolArguments
        struct Config {
            @ToolArgument("Enabled features")
            var features: [String]
            
            @ToolArgument("Settings map")
            var settings: [String: Int]
        }
    }
    
    public init() {}
    
    public func call(arguments: Arguments) async throws -> ToolOutput {
        return ToolOutput(data: [
            "data_size": arguments.data.count,
            "sum": arguments.numbers.reduce(0, +),
            "status": arguments.status,
            "feature_count": arguments.config.features.count
        ])
    }
}

/// Test tool that produces large output
@Tool("generate_report")
public struct LargeOutputTool {
    public let description = "Generate a large report"
    
    @ToolArguments
    public struct Arguments {
        @ToolArgument("Report size in KB")
        var sizeKB: Int
    }
    
    public init() {}
    
    public func call(arguments: Arguments) async throws -> ToolOutput {
        // Generate large string
        let chunk = String(repeating: "Lorem ipsum dolor sit amet. ", count: 35) // ~1KB
        let content = String(repeating: chunk, count: arguments.sizeKB)
        
        return ToolOutput(data: [
            "report": content,
            "size_bytes": content.count
        ])
    }
}