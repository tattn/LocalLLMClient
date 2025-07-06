import Testing
import Foundation
@testable import LocalLLMClient
import LocalLLMClientMacros

// Test nested arrays and complex array types

@ToolArguments
struct Item {
    @ToolArgument("Item name")
    var name: String
    
    @ToolArgument("Item value")
    var value: Double
}

// Manual implementation without macro for complex types
struct ComplexArraySchema: ToolSchemaGeneratable {
    var nestedStringArrays: [[String]]
    var optionalStrings: [String?]
    var optionalArrayOfOptionals: [String?]?
    var items: [Item]
    var matrix: [[Int]]
    
    static var argumentsSchema: LLMToolArgumentsSchema {
        [
            "nestedStringArrays": .array(
                of: .array(of: .string(description: "String"), description: "String array"),
                description: "Array of arrays of strings"
            ),
            "optionalStrings": .array(
                of: .optional(.string(description: "Optional string", format: nil)),
                description: "Array of optional strings"
            ),
            "optionalArrayOfOptionals": .optional(
                .array(
                    of: .optional(.string(description: "Optional string", format: nil)),
                    description: "Optional array of optional strings"
                )
            ),
            "items": .array(
                of: .object(Item.self, description: "Item"),
                description: "Array of custom objects"
            ),
            "matrix": .array(
                of: .array(of: .integer(description: "Integer"), description: "Integer array"),
                description: "Array of arrays of integers"
            )
        ]
    }
}

@Test
func testNestedArraySchema() async throws {
    let schema = ComplexArraySchema.generateSchema()
    let properties = try #require(schema["properties"] as? [String: [String: any Sendable]])
    
    // Test nested string arrays
    let nestedArrayProp = try #require(properties["nestedStringArrays"])
    #expect(nestedArrayProp["type"] as? String == "array")
    let nestedItems = try #require(nestedArrayProp["items"] as? [String: any Sendable])
    #expect(nestedItems["type"] as? String == "array")
    let innerItems = try #require(nestedItems["items"] as? [String: String])
    #expect(innerItems["type"] == "string")
    
    // Test array of optional strings
    let optionalStringsProp = try #require(properties["optionalStrings"])
    #expect(optionalStringsProp["type"] as? String == "array")
    let optionalItems = try #require(optionalStringsProp["items"] as? [String: any Sendable])
    let oneOf = try #require(optionalItems["oneOf"] as? [[String: String]])
    #expect(oneOf.count == 2)
    #expect(oneOf.contains { $0["type"] == "string" })
    #expect(oneOf.contains { $0["type"] == "null" })
    
    // Test optional array of optionals
    let optionalArrayProp = try #require(properties["optionalArrayOfOptionals"])
    #expect(optionalArrayProp["type"] as? String == "array")
    
    // Test array of custom objects
    let itemsProp = try #require(properties["items"])
    #expect(itemsProp["type"] as? String == "array")
    let itemsSchema = try #require(itemsProp["items"] as? [String: any Sendable])
    #expect(itemsSchema["type"] as? String == "object")
    let itemProperties = try #require(itemsSchema["properties"] as? [String: [String: any Sendable]])
    #expect(itemProperties["name"]?["type"] as? String == "string")
    #expect(itemProperties["value"]?["type"] as? String == "number")
    
    // Test matrix (array of arrays)
    let matrixProp = try #require(properties["matrix"])
    #expect(matrixProp["type"] as? String == "array")
    let matrixItems = try #require(matrixProp["items"] as? [String: any Sendable])
    #expect(matrixItems["type"] as? String == "array")
    let matrixInnerItems = try #require(matrixItems["items"] as? [String: String])
    #expect(matrixInnerItems["type"] == "integer")
}

// Test using LLMToolArgumentType directly
@Test
func testLLMToolArgumentTypeArrayHandling() async throws {
    // Test basic array types
    let stringArraySchema: LLMToolArgumentsSchema = [
        "tags": .array(of: .string(description: "Tag"), description: "List of tags")
    ]
    
    let schema = generateToolSchema(from: stringArraySchema)
    let properties = try #require(schema["properties"] as? [String: [String: any Sendable]])
    
    let tagsProp = try #require(properties["tags"])
    #expect(tagsProp["type"] as? String == "array")
    #expect(tagsProp["description"] as? String == "List of tags")
    
    let items = try #require(tagsProp["items"] as? [String: any Sendable])
    #expect(items["type"] as? String == "string")
}

@Test
func testComplexLLMToolArgumentTypes() async throws {
    let complexSchema: LLMToolArgumentsSchema = [
        "matrix": .array(
            of: .array(of: .integer(description: "Value"), description: "Row"),
            description: "2D matrix"
        ),
        "optionalStrings": .array(
            of: .optional(.string(description: "Optional string", format: nil)),
            description: "Array of optional strings"
        ),
        "enumArray": .array(
            of: .enum(values: ["red", "green", "blue"], description: "Color"),
            description: "Array of colors"
        )
    ]
    
    let schema = generateToolSchema(from: complexSchema)
    let properties = try #require(schema["properties"] as? [String: [String: any Sendable]])
    
    // Test nested array (matrix)
    let matrixProp = try #require(properties["matrix"])
    #expect(matrixProp["type"] as? String == "array")
    let matrixItems = try #require(matrixProp["items"] as? [String: any Sendable])
    #expect(matrixItems["type"] as? String == "array")
    
    // Test array of optionals
    let optionalsProp = try #require(properties["optionalStrings"])
    #expect(optionalsProp["type"] as? String == "array")
    let optionalItems = try #require(optionalsProp["items"] as? [String: any Sendable])
    #expect(optionalItems["oneOf"] != nil)
    
    // Test array of enums
    let enumArrayProp = try #require(properties["enumArray"])
    #expect(enumArrayProp["type"] as? String == "array")
    let enumItems = try #require(enumArrayProp["items"] as? [String: any Sendable])
    #expect(enumItems["type"] as? String == "string")
    #expect(enumItems["enum"] as? [String] == ["red", "green", "blue"])
}

@Test
func testArrayWithFormats() async throws {
    let schemaWithFormats: LLMToolArgumentsSchema = [
        "base64Images": .array(
            of: .string(description: "Base64 image", format: "byte"),
            description: "Array of base64 encoded images"
        ),
        "timestamps": .array(
            of: .string(description: "Timestamp", format: "date-time"),
            description: "Array of timestamps"
        )
    ]
    
    let schema = generateToolSchema(from: schemaWithFormats)
    let properties = try #require(schema["properties"] as? [String: [String: any Sendable]])
    
    // Test array of base64 strings
    let imagesProp = try #require(properties["base64Images"])
    #expect(imagesProp["type"] as? String == "array")
    let imageItems = try #require(imagesProp["items"] as? [String: any Sendable])
    #expect(imageItems["type"] as? String == "string")
    #expect(imageItems["format"] as? String == "byte")
    
    // Test array of timestamps
    let timestampsProp = try #require(properties["timestamps"])
    #expect(timestampsProp["type"] as? String == "array")
    let timestampItems = try #require(timestampsProp["items"] as? [String: any Sendable])
    #expect(timestampItems["type"] as? String == "string")
    #expect(timestampItems["format"] as? String == "date-time")
}

// Test edge case: deeply nested arrays
@Test
func testDeeplyNestedArrays() async throws {
    let deepSchema: LLMToolArgumentsSchema = [
        "deepArray": .array(
            of: .array(
                of: .array(
                    of: .string(description: "Value"),
                    description: "Inner array"
                ),
                description: "Middle array"
            ),
            description: "Outer array"
        )
    ]
    
    let schema = generateToolSchema(from: deepSchema)
    let properties = try #require(schema["properties"] as? [String: [String: any Sendable]])
    
    let deepProp = try #require(properties["deepArray"])
    #expect(deepProp["type"] as? String == "array")
    
    let level1 = try #require(deepProp["items"] as? [String: any Sendable])
    #expect(level1["type"] as? String == "array")
    
    let level2 = try #require(level1["items"] as? [String: any Sendable])
    #expect(level2["type"] as? String == "array")
    
    let level3 = try #require(level2["items"] as? [String: any Sendable])
    #expect(level3["type"] as? String == "string")
}