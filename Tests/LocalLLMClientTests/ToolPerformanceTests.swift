import Testing
import Foundation
import LocalLLMClient
import LocalLLMClientCore
import LocalLLMClientMacros
import LocalLLMClientTestUtilities

/// Performance and concurrency tests for tool calling functionality
@Suite(.disabled(if: TestEnvironment.onGitHubAction))
struct ToolPerformanceTests {
    
    // MARK: - Concurrency Tests
    
    @Test
    func testConcurrentToolExecution() async throws {
        struct ConcurrentTool: LLMTool {
            let name: String
            let delay: Double
            
            var description: String { "Tool \(name) with \(delay)s delay" }
            
            struct Arguments: Decodable, ToolSchemaGeneratable {
                let input: String
                
                static var argumentsSchema: LLMToolArgumentsSchema {
                    ["input": .string(description: "Input value")]
                }
            }
            
            func call(arguments: Arguments) async throws -> ToolOutput {
                let start = Date()
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                let elapsed = Date().timeIntervalSince(start)
                
                return ToolOutput(data: [
                    "tool": name,
                    "input": arguments.input,
                    "elapsed": elapsed
                ])
            }
        }
        
        // Create multiple tools with different delays
        let tools = [
            AnyLLMTool(ConcurrentTool(name: "fast_tool", delay: 0.1)),
            AnyLLMTool(ConcurrentTool(name: "medium_tool", delay: 0.2)),
            AnyLLMTool(ConcurrentTool(name: "slow_tool", delay: 0.3))
        ]
        
        // Simulate concurrent tool calls
        let toolCalls = [
            LLMToolCall(id: "1", name: "fast_tool", arguments: #"{"input": "fast"}"#),
            LLMToolCall(id: "2", name: "medium_tool", arguments: #"{"input": "medium"}"#),
            LLMToolCall(id: "3", name: "slow_tool", arguments: #"{"input": "slow"}"#)
        ]
        
        let start = Date()
        
        // Execute tools concurrently
        let results = try await withThrowingTaskGroup(of: (String, ToolOutput).self) { group in
            for toolCall in toolCalls {
                guard let tool = tools.first(where: { $0.name == toolCall.name }) else {
                    continue
                }
                
                group.addTask {
                    let output = try await tool.call(argumentsJSON: toolCall.arguments)
                    return (toolCall.id, output)
                }
            }
            
            var outputs: [(String, ToolOutput)] = []
            for try await result in group {
                outputs.append(result)
            }
            return outputs
        }
        
        let totalElapsed = Date().timeIntervalSince(start)
        
        // Verify all tools executed
        #expect(results.count == 3)
        
        // Verify concurrent execution (should take ~0.3s, not 0.6s)
        #expect(totalElapsed < 0.4)
        #expect(totalElapsed >= 0.3)
    }
    
    @Test
    func testToolExecutionWithRaceCondition() async throws {
        // Shared mutable state to test thread safety
        actor Counter {
            private var value = 0
            
            func increment() -> Int {
                value += 1
                return value
            }
            
            func getValue() -> Int {
                return value
            }
        }
        
        struct RaceTool: LLMTool {
            let name = "race_tool"
            let description = "Tool for testing race conditions"
            let counter: Counter
            
            struct Arguments: Decodable, ToolSchemaGeneratable {
                let id: Int
                
                static var argumentsSchema: LLMToolArgumentsSchema {
                    ["id": .integer(description: "Request ID")]
                }
            }
            
            func call(arguments: Arguments) async throws -> ToolOutput {
                // Simulate some work
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                
                let count = await counter.increment()
                
                return ToolOutput(data: [
                    "id": arguments.id,
                    "count": count
                ])
            }
        }
        
        let counter = Counter()
        let tool = RaceTool(counter: counter)
        let anyTool = AnyLLMTool(tool)
        
        // Create many concurrent calls
        let concurrentCalls = 100
        
        let results = try await withThrowingTaskGroup(of: ToolOutput.self) { group in
            for i in 0..<concurrentCalls {
                group.addTask {
                    try await anyTool.call(argumentsJSON: #"{"id": \#(i)}"#)
                }
            }
            
            var outputs: [ToolOutput] = []
            for try await result in group {
                outputs.append(result)
            }
            return outputs
        }
        
        // Verify all calls completed
        #expect(results.count == concurrentCalls)
        
        // Verify counter is thread-safe
        let finalCount = await counter.getValue()
        #expect(finalCount == concurrentCalls)
    }
    
    // MARK: - Performance Tests
    
    @Test
    func testLargeToolResponse() async throws {
        struct LargeTool: LLMTool {
            let name = "large_tool"
            let description = "Tool that returns large responses"
            
            struct Arguments: Decodable, ToolSchemaGeneratable {
                let size: Int
                
                static var argumentsSchema: LLMToolArgumentsSchema {
                    ["size": .integer(description: "Response size in items")]
                }
            }
            
            func call(arguments: Arguments) async throws -> ToolOutput {
                // Generate large response
                var data: [String: any Sendable] = [:]
                
                // Create array with specified size
                let items: [[String: any Sendable]] = (0..<arguments.size).map { index in
                    [
                        "id": index,
                        "value": "Item \(index)",
                        "metadata": [
                            "created": Date().timeIntervalSince1970,
                            "tags": ["tag1", "tag2", "tag3"],
                            "properties": [
                                "key1": "value1",
                                "key2": "value2",
                                "key3": "value3"
                            ] as [String: any Sendable]
                        ] as [String: any Sendable]
                    ]
                }
                
                data["items"] = items
                data["count"] = arguments.size
                
                return ToolOutput(data: data)
            }
        }
        
        let tool = LargeTool()
        let anyTool = AnyLLMTool(tool)
        
        // Test with increasingly large responses
        let sizes = [10, 100, 1000]
        
        for size in sizes {
            let start = Date()
            let result = try await anyTool.call(argumentsJSON: #"{"size": \#(size)}"#)
            let elapsed = Date().timeIntervalSince(start)
            
            #expect(result.data["count"] as? Int == size)
            
            // Performance should be reasonable even for large responses
            #expect(elapsed < 1.0)
        }
    }
    
    @Test("Tool lookup performance with moderate number of tools")
    func testManyToolsPerformance() async throws {
        struct SimpleTool: LLMTool {
            let name: String
            var description: String { "Tool \(name)" }
            
            struct Arguments: Decodable, ToolSchemaGeneratable {
                let value: String
                
                static var argumentsSchema: LLMToolArgumentsSchema {
                    ["value": .string(description: "Value")]
                }
            }
            
            func call(arguments: Arguments) async throws -> ToolOutput {
                return ToolOutput(data: ["result": arguments.value])
            }
        }
        
        // Create a moderate number of tools (enough to test performance)
        let toolCount = 20
        let tools = (0..<toolCount).map { i in
            AnyLLMTool(SimpleTool(name: "tool_\(i)"))
        }
        
        // Create ToolExecutor for O(1) lookup performance
        let executor = ToolExecutor(tools: tools)
        
        // Test tool execution performance
        let start = Date()
        
        // Execute random tools
        let toolCalls = (0..<50).map { _ in
            let randomIndex = Int.random(in: 0..<toolCount)
            return LLMToolCall(
                id: UUID().uuidString,
                name: "tool_\(randomIndex)",
                arguments: #"{"value": "test"}"#
            )
        }
        
        let results = await executor.executeBatch(toolCalls)
        let elapsed = Date().timeIntervalSince(start)
        
        // Verify all calls succeeded
        #expect(results.allSatisfy { result in
            if case .success = result { return true }
            return false
        })
        
        // Should complete quickly with O(1) lookup
        #expect(elapsed < 0.5)
    }
    
    @Test
    func testToolSchemaGenerationPerformance() async throws {
        struct ComplexSchemaTool: LLMTool {
            let name = "complex_schema"
            let description = "Tool with complex schema"
            
            struct Arguments: Decodable, ToolSchemaGeneratable {
                let string1: String
                let string2: String
                let int1: Int
                let int2: Int
                let bool1: Bool
                let bool2: Bool
                let array1: [String]
                let array2: [Int]
                let nested1: Nested1
                let nested2: Nested2
                
                struct Nested1: Decodable, ToolSchemaGeneratable, ToolArgumentObject {
                    let field1: String
                    let field2: Int
                    let field3: Bool
                    
                    static var argumentsSchema: LLMToolArgumentsSchema {
                        [
                            "field1": .string(description: "Field 1"),
                            "field2": .integer(description: "Field 2"),
                            "field3": .boolean(description: "Field 3")
                        ]
                    }
                }
                
                struct Nested2: Decodable, ToolSchemaGeneratable, ToolArgumentObject {
                    let items: [Item]
                    
                    struct Item: Decodable, ToolSchemaGeneratable, ToolArgumentObject {
                        let id: String
                        let value: Double
                        
                        static var argumentsSchema: LLMToolArgumentsSchema {
                            [
                                "id": .string(description: "ID"),
                                "value": .number(description: "Value")
                            ]
                        }
                    }
                    
                    static var argumentsSchema: LLMToolArgumentsSchema {
                        ["items": .array(of: .object(ComplexSchemaTool.Arguments.Nested2.Item.self, description: "Item"), description: "Items")]
                    }
                }
                
                static var argumentsSchema: LLMToolArgumentsSchema {
                    [
                        "string1": .string(description: "String 1"),
                        "string2": .string(description: "String 2"),
                        "int1": .integer(description: "Int 1"),
                        "int2": .integer(description: "Int 2"),
                        "bool1": .boolean(description: "Bool 1"),
                        "bool2": .boolean(description: "Bool 2"),
                        "array1": .array(of: .string(description: "String"), description: "Array 1"),
                        "array2": .array(of: .integer(description: "Int"), description: "Array 2"),
                        "nested1": .object(ComplexSchemaTool.Arguments.Nested1.self, description: "Nested 1"),
                        "nested2": .object(ComplexSchemaTool.Arguments.Nested2.self, description: "Nested 2")
                    ]
                }
            }
            
            func call(arguments: Arguments) async throws -> ToolOutput {
                return ToolOutput(data: ["success": true])
            }
        }
        
        let tool = ComplexSchemaTool()
        let anyTool = AnyLLMTool(tool)
        
        // Measure schema generation performance
        let start = Date()
        
        // Generate schema multiple times (reduced from 100 to test actual performance)
        for _ in 0..<20 {
            _ = anyTool.toOAICompatJSON()
        }
        
        let elapsed = Date().timeIntervalSince(start)
        
        // Schema generation should be fast even for complex schemas
        #expect(elapsed < 0.1) // Tightened expectation since we reduced iterations
    }
    
    // MARK: - Memory Tests
    
    @Test
    func testToolMemoryRetention() async throws {
        class MemoryTracker {
            weak var toolReference: AnyObject?
            
            func setReference(_ obj: AnyObject) {
                toolReference = obj
            }
            
            func hasReference() -> Bool {
                return toolReference != nil
            }
        }
        
        let tracker = MemoryTracker()
        
        // Create tool in isolated scope
        do {
            final class MemoryTool: LLMTool {
                let name = "memory_tool"
                let description = "Tool for memory testing"
                let data: [String] // Large data to make memory usage noticeable
                
                init(data: [String]) {
                    self.data = data
                }
                
                struct Arguments: Decodable, ToolSchemaGeneratable {
                    let input: String
                    
                    static var argumentsSchema: LLMToolArgumentsSchema {
                        ["input": .string(description: "Input")]
                    }
                }
                
                func call(arguments: Arguments) async throws -> ToolOutput {
                    return ToolOutput(data: ["size": data.count])
                }
            }
            
            // Create tool with large data
            let largeData = (0..<1000).map { "Item \($0)" }
            let tool = MemoryTool(data: largeData)
            let anyTool = AnyLLMTool(tool)
            
            // Track reference to the underlying tool
            tracker.setReference(tool as AnyObject)
            
            // Use the tool
            _ = try await anyTool.call(argumentsJSON: #"{"input": "test"}"#)
            
            // Verify tool exists
            #expect(tracker.hasReference())
        }
        
        // Tool should be deallocated after leaving scope
        // Note: In real tests, you might need to wait or force GC
        #expect(!tracker.hasReference())
    }
}
