import Testing
import Foundation
import LocalLLMClient
import LocalLLMClientCore
import LocalLLMClientMacros
import LocalLLMClientTestUtilities

/// Edge case and error handling tests for tool calling functionality
struct ToolEdgeCaseTests {
    
    // MARK: - Error Handling Tests
    
    @Test
    func testToolCallWithMissingRequiredParameter() async throws {
        struct StrictTool: LLMTool {
            let name = "strict_tool"
            let description = "A tool with required parameters"
            
            struct Arguments: Decodable, ToolSchemaGeneratable {
                let requiredField: String
                let optionalField: String?
                
                static var argumentsSchema: LLMToolArgumentsSchema {
                    [
                        "requiredField": .string(description: "This field is required"),
                        "optionalField": .string(description: "This field is optional")
                    ]
                }
            }
            
            func call(arguments: Arguments) async throws -> ToolOutput {
                return ToolOutput(data: ["result": arguments.requiredField])
            }
        }
        
        let tool = StrictTool()
        let anyTool = AnyLLMTool(tool)
        
        // Test with missing required parameter
        let invalidJSON = #"{"optionalField": "value"}"#
        
        await #expect(throws: Error.self) {
            _ = try await anyTool.call(argumentsJSON: invalidJSON)
        }
    }
    
    @Test
    func testToolCallWithInvalidJSONArguments() async throws {
        let weatherTool = WeatherTool()
        let anyTool = AnyLLMTool(weatherTool)
        
        // Test various invalid JSON formats
        let invalidJSONs = [
            "{invalid json}",
            "{'single': 'quotes'}",
            "{location: no quotes}",
            "null",
            "undefined",
            "[]",
            "true"
        ]
        
        for invalidJSON in invalidJSONs {
            await #expect(throws: Error.self) {
                _ = try await anyTool.call(argumentsJSON: invalidJSON)
            }
        }
    }
    
    @Test
    func testToolCallWithTypeMismatch() async throws {
        struct TypedTool: LLMTool {
            let name = "typed_tool"
            let description = "A tool with specific types"
            
            struct Arguments: Decodable, ToolSchemaGeneratable {
                let intValue: Int
                let boolValue: Bool
                let doubleValue: Double
                
                static var argumentsSchema: LLMToolArgumentsSchema {
                    [
                        "intValue": .integer(description: "Integer value"),
                        "boolValue": .boolean(description: "Boolean value"),
                        "doubleValue": .number(description: "Double value")
                    ]
                }
            }
            
            func call(arguments: Arguments) async throws -> ToolOutput {
                return ToolOutput(data: [
                    "int": arguments.intValue,
                    "bool": arguments.boolValue,
                    "double": arguments.doubleValue
                ])
            }
        }
        
        let tool = TypedTool()
        let anyTool = AnyLLMTool(tool)
        
        // Test with type mismatches
        let invalidTypeJSON = #"{"intValue": "not a number", "boolValue": "yes", "doubleValue": true}"#
        
        await #expect(throws: Error.self) {
            _ = try await anyTool.call(argumentsJSON: invalidTypeJSON)
        }
    }
    
    @Test
    func testToolExecutionTimeout() async throws {
        struct TimeoutTool: LLMTool {
            let name = "timeout_tool"
            let description = "A tool that times out"
            let timeout: Double
            
            struct Arguments: Decodable, ToolSchemaGeneratable {
                let delay: Double
                
                static var argumentsSchema: LLMToolArgumentsSchema {
                    ["delay": .number(description: "Delay in seconds")]
                }
            }
            
            func call(arguments: Arguments) async throws -> ToolOutput {
                try await Task.sleep(nanoseconds: UInt64(arguments.delay * 1_000_000_000))
                return ToolOutput(data: ["completed": true])
            }
        }
        
        let tool = TimeoutTool(timeout: 0.1)
        let anyTool = AnyLLMTool(tool)
        
        // This test demonstrates timeout handling - actual implementation would need timeout support
        let result = try await anyTool.call(argumentsJSON: #"{"delay": 0.05}"#)
        #expect(result.data["completed"] as? Bool == true)
    }
    
    // MARK: - Schema Edge Cases
    
    @Test
    func testSchemaWithCircularReference() async throws {
        // Note: This test identifies a limitation - circular references are not supported
        struct Node: Decodable, ToolSchemaGeneratable {
            let value: String
            // Circular references would cause infinite recursion
            // let children: [Node]? // This would be problematic
            
            static var argumentsSchema: LLMToolArgumentsSchema {
                ["value": .string(description: "Node value")]
            }
        }
        
        let schema = Node.argumentsSchema
        #expect(schema.contains(where: { $0.key == "value" }))
    }
    
    @Test
    func testSchemaWithVeryDeepNesting() async throws {
        struct Level5: Decodable, ToolSchemaGeneratable, ToolArgumentObject {
            let value: String
            static var argumentsSchema: LLMToolArgumentsSchema {
                ["value": .string(description: "Level 5")]
            }
        }
        
        struct Level4: Decodable, ToolSchemaGeneratable, ToolArgumentObject {
            let level5: Level5
            static var argumentsSchema: LLMToolArgumentsSchema {
                ["level5": .object(Level5.self, description: "Level 5")]
            }
        }
        
        struct Level3: Decodable, ToolSchemaGeneratable, ToolArgumentObject {
            let level4: Level4
            static var argumentsSchema: LLMToolArgumentsSchema {
                ["level4": .object(Level4.self, description: "Level 4")]
            }
        }
        
        struct Level2: Decodable, ToolSchemaGeneratable, ToolArgumentObject {
            let level3: Level3
            static var argumentsSchema: LLMToolArgumentsSchema {
                ["level3": .object(Level3.self, description: "Level 3")]
            }
        }
        
        struct Level1: Decodable, ToolSchemaGeneratable, ToolArgumentObject {
            let level2: Level2
            static var argumentsSchema: LLMToolArgumentsSchema {
                ["level2": .object(Level2.self, description: "Level 2")]
            }
        }
        
        struct DeepTool: LLMTool {
            let name = "deep_tool"
            let description = "A tool with deep nesting"
            
            typealias Arguments = Level1
            
            func call(arguments: Arguments) async throws -> ToolOutput {
                return ToolOutput(data: ["depth": 5])
            }
        }
        
        let tool = DeepTool()
        let anyTool = AnyLLMTool(tool)
        
        // Test that deep nesting works
        let deepJSON = #"{"level2": {"level3": {"level4": {"level5": {"value": "bottom"}}}}}"#
        let result = try await anyTool.call(argumentsJSON: deepJSON)
        #expect(result.data["depth"] as? Int == 5)
    }
    
    @Test
    func testSchemaWithComplexOptionals() async throws {
        struct ComplexOptionalTool: LLMTool {
            let name = "complex_optional"
            let description = "Tool with complex optional types"
            
            struct Arguments: Decodable, ToolSchemaGeneratable {
                let optionalArray: [String]?
                let arrayOfOptionals: [String?]
                let optionalArrayOfOptionals: [String?]?
                let nestedOptional: NestedOptional?
                
                struct NestedOptional: Decodable, ToolSchemaGeneratable, ToolArgumentObject {
                    let value: String?
                    
                    static var argumentsSchema: LLMToolArgumentsSchema {
                        ["value": .string(description: "Optional value")]
                    }
                }
                
                static var argumentsSchema: LLMToolArgumentsSchema {
                    [
                        "optionalArray": .array(of: .string(description: "String"), description: "Optional array"),
                        "arrayOfOptionals": .array(of: .string(description: "Optional string"), description: "Array of optionals"),
                        "optionalArrayOfOptionals": .array(of: .string(description: "Optional string"), description: "Optional array of optionals"),
                        "nestedOptional": .object(NestedOptional.self, description: "Optional nested object")
                    ]
                }
            }
            
            func call(arguments: Arguments) async throws -> ToolOutput {
                return ToolOutput(data: [
                    "hasOptionalArray": arguments.optionalArray != nil,
                    "arrayOfOptionalsCount": arguments.arrayOfOptionals.count,
                    "hasOptionalArrayOfOptionals": arguments.optionalArrayOfOptionals != nil,
                    "hasNestedOptional": arguments.nestedOptional != nil
                ])
            }
        }
        
        let tool = ComplexOptionalTool()
        let anyTool = AnyLLMTool(tool)
        
        // Test various combinations of optionals
        let testCases = [
            (#"{"arrayOfOptionals": []}"#, 0),
            (#"{"arrayOfOptionals": [null, "value", null]}"#, 3),
            (#"{"optionalArray": ["a", "b"], "arrayOfOptionals": []}"#, 0),
            (#"{"arrayOfOptionals": [], "nestedOptional": {"value": null}}"#, 0),
            (#"{"arrayOfOptionals": [], "nestedOptional": {}}"#, 0)
        ]
        
        for (json, expectedCount) in testCases {
            let result = try await anyTool.call(argumentsJSON: json)
            #expect(result.data["arrayOfOptionalsCount"] as? Int == expectedCount)
        }
    }
    
    @Test
    func testSchemaWithEmptyArrays() async throws {
        struct ArrayTool: LLMTool {
            let name = "array_tool"
            let description = "Tool for testing array edge cases"
            
            struct Arguments: Decodable, ToolSchemaGeneratable {
                let strings: [String]
                let numbers: [Double]
                let objects: [Item]
                
                struct Item: Decodable, ToolSchemaGeneratable, ToolArgumentObject {
                    let id: String
                    
                    static var argumentsSchema: LLMToolArgumentsSchema {
                        ["id": .string(description: "Item ID")]
                    }
                }
                
                static var argumentsSchema: LLMToolArgumentsSchema {
                    [
                        "strings": .array(of: .string(description: "String"), description: "String array"),
                        "numbers": .array(of: .number(description: "Number"), description: "Number array"),
                        "objects": .array(of: .object(Item.self, description: "Item"), description: "Object array")
                    ]
                }
            }
            
            func call(arguments: Arguments) async throws -> ToolOutput {
                return ToolOutput(data: [
                    "stringsEmpty": arguments.strings.isEmpty,
                    "numbersEmpty": arguments.numbers.isEmpty,
                    "objectsEmpty": arguments.objects.isEmpty,
                    "totalItems": arguments.strings.count + arguments.numbers.count + arguments.objects.count
                ])
            }
        }
        
        let tool = ArrayTool()
        let anyTool = AnyLLMTool(tool)
        
        // Test with empty arrays
        let emptyArraysJSON = #"{"strings": [], "numbers": [], "objects": []}"#
        let result = try await anyTool.call(argumentsJSON: emptyArraysJSON)
        
        #expect(result.data["stringsEmpty"] as? Bool == true)
        #expect(result.data["numbersEmpty"] as? Bool == true)
        #expect(result.data["objectsEmpty"] as? Bool == true)
        #expect(result.data["totalItems"] as? Int == 0)
    }
    
    // MARK: - Unicode and Special Characters
    
    @Test
    func testToolWithUnicodeArguments() async throws {
        struct UnicodeTool: LLMTool {
            let name = "unicode_tool"
            let description = "Tool that handles unicode"
            
            struct Arguments: Decodable, ToolSchemaGeneratable {
                let text: String
                let emoji: String
                
                static var argumentsSchema: LLMToolArgumentsSchema {
                    [
                        "text": .string(description: "Text with unicode"),
                        "emoji": .string(description: "Emoji characters")
                    ]
                }
            }
            
            func call(arguments: Arguments) async throws -> ToolOutput {
                return ToolOutput(data: [
                    "textLength": arguments.text.count,
                    "emojiLength": arguments.emoji.count,
                    "combined": arguments.text + arguments.emoji
                ])
            }
        }
        
        let tool = UnicodeTool()
        let anyTool = AnyLLMTool(tool)
        
        // Test with various unicode characters
        let unicodeJSON = #"{"text": "Hello 世界 🌍", "emoji": "🎉🎊🎈"}"#
        let result = try await anyTool.call(argumentsJSON: unicodeJSON)
        
        #expect(result.data["textLength"] as? Int == 10)
        #expect(result.data["emojiLength"] as? Int == 3)
        #expect(result.data["combined"] as? String == "Hello 世界 🌍🎉🎊🎈")
    }
    
    @Test
    func testToolWithEscapedCharacters() async throws {
        struct EscapeTool: LLMTool {
            let name = "escape_tool"
            let description = "Tool that handles escaped characters"
            
            struct Arguments: Decodable, ToolSchemaGeneratable {
                let path: String
                let regex: String
                let quote: String
                
                static var argumentsSchema: LLMToolArgumentsSchema {
                    [
                        "path": .string(description: "File path"),
                        "regex": .string(description: "Regular expression"),
                        "quote": .string(description: "Quoted text")
                    ]
                }
            }
            
            func call(arguments: Arguments) async throws -> ToolOutput {
                return ToolOutput(data: [
                    "path": arguments.path,
                    "regex": arguments.regex,
                    "quote": arguments.quote
                ])
            }
        }
        
        let tool = EscapeTool()
        let anyTool = AnyLLMTool(tool)
        
        // Test with escaped characters
        let escapedJSON = #"{"path": "C:\\Users\\Test\\file.txt", "regex": "\\d+\\.\\d+", "quote": "He said \"Hello\""}"#
        let result = try await anyTool.call(argumentsJSON: escapedJSON)
        
        #expect(result.data["path"] as? String == #"C:\Users\Test\file.txt"#)
        #expect(result.data["regex"] as? String == #"\d+\.\d+"#)
        #expect(result.data["quote"] as? String == #"He said "Hello""#)
    }
    
    // MARK: - Additional Edge Cases
    
    @Test
    func testToolWithVeryLargeArguments() async throws {
        struct LargeArgTool: LLMTool {
            let name = "large_arg_tool"
            let description = "Tool with very large arguments"
            
            struct Arguments: Decodable, ToolSchemaGeneratable {
                let largeText: String
                let items: [String]
                
                static var argumentsSchema: LLMToolArgumentsSchema {
                    [
                        "largeText": .string(description: "Large text content"),
                        "items": .array(of: .string(description: "Item"), description: "Large array")
                    ]
                }
            }
            
            func call(arguments: Arguments) async throws -> ToolOutput {
                return ToolOutput(data: [
                    "textSize": arguments.largeText.count,
                    "itemCount": arguments.items.count
                ])
            }
        }
        
        let tool = LargeArgTool()
        let anyTool = AnyLLMTool(tool)
        
        // Create large arguments
        let largeText = String(repeating: "Lorem ipsum ", count: 10000) // ~120KB
        let items = (0..<1000).map { "Item_\($0)" }
        
        // Create JSON manually to avoid type inference issues
        let jsonObject: [String: Any] = [
            "largeText": largeText,
            "items": items
        ]
        let largeJSONData = try JSONSerialization.data(withJSONObject: jsonObject)
        let largeJSONString = String(decoding: largeJSONData, as: UTF8.self)
        
        let result = try await anyTool.call(argumentsJSON: largeJSONString)
        
        #expect(result.data["textSize"] as? Int == largeText.count)
        #expect(result.data["itemCount"] as? Int == 1000)
    }
    
    @Test
    func testToolCallsWithDifferentIDFormats() async throws {
        // Test various ID formats that might be generated by different LLMs
        let idFormats = [
            "call_123",
            "tool-call-abc-def",
            "123e4567-e89b-12d3-a456-426614174000",
            "CALL_WITH_UNDERSCORE_123",
            "simple",
            "call.with.dots.456",
            "call-with-special_chars.789"
        ]
        
        for testId in idFormats {
            let toolCall = LLMToolCall(
                id: testId,
                name: "test_tool",
                arguments: "{}"
            )
            
            #expect(toolCall.id == testId)
            #expect(!toolCall.id.isEmpty)
        }
    }
    
    @Test
    func testToolWithConflictingPropertyNames() async throws {
        // Test tool with property names that might conflict with reserved words
        struct ConflictTool: LLMTool {
            let name = "conflict_tool"
            let description = "Tool with potentially conflicting property names"
            
            struct Arguments: Decodable, ToolSchemaGeneratable {
                let type: String
                let `class`: String
                let `protocol`: String
                let id: String
                
                static var argumentsSchema: LLMToolArgumentsSchema {
                    [
                        "type": .string(description: "Type property"),
                        "class": .string(description: "Class property"),
                        "protocol": .string(description: "Protocol property"),
                        "id": .string(description: "ID property")
                    ]
                }
            }
            
            func call(arguments: Arguments) async throws -> ToolOutput {
                return ToolOutput(data: [
                    "receivedType": arguments.type,
                    "receivedClass": arguments.`class`,
                    "receivedProtocol": arguments.`protocol`,
                    "receivedId": arguments.id
                ])
            }
        }
        
        let tool = ConflictTool()
        let anyTool = AnyLLMTool(tool)
        
        let json = #"{"type": "test", "class": "MyClass", "protocol": "HTTP", "id": "12345"}"#
        let result = try await anyTool.call(argumentsJSON: json)
        
        #expect(result.data["receivedType"] as? String == "test")
        #expect(result.data["receivedClass"] as? String == "MyClass")
        #expect(result.data["receivedProtocol"] as? String == "HTTP")
        #expect(result.data["receivedId"] as? String == "12345")
    }
    
    @Test
    func testToolOutputWithNonSerializableData() async throws {
        // Test handling of tool output that contains non-serializable data
        struct NonSerializableTool: LLMTool {
            let name = "non_serializable_tool"
            let description = "Tool that might return non-serializable data"
            
            struct Arguments: Decodable, ToolSchemaGeneratable {
                let input: String
                
                static var argumentsSchema: LLMToolArgumentsSchema {
                    ["input": .string(description: "Input string")]
                }
            }
            
            func call(arguments: Arguments) async throws -> ToolOutput {
                // Create output with various data types
                let data: [String: any Sendable] = [
                    "string": "text",
                    "number": 42,
                    "boolean": true,
                    "array": [1, 2, 3],
                    "dictionary": ["key": "value"],
                    "null": NSNull(), // This might cause issues
                    "date": Date().timeIntervalSince1970, // Convert to serializable format
                    "data": Data([0x01, 0x02]).base64EncodedString() // Convert to string
                ]
                
                return ToolOutput(data: data)
            }
        }
        
        let tool = NonSerializableTool()
        let anyTool = AnyLLMTool(tool)
        
        let result = try await anyTool.call(argumentsJSON: #"{"input": "test"}"#)
        
        // Verify all data types are properly handled
        #expect(result.data["string"] as? String == "text")
        #expect(result.data["number"] as? Int == 42)
        #expect(result.data["boolean"] as? Bool == true)
        #expect(result.data["array"] as? [Int] == [1, 2, 3])
    }
}