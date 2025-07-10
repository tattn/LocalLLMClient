import Testing
import Foundation
@testable import LocalLLMClientCore
import LocalLLMClientMacros

// MARK: - Test Types

// Basic types test
@ToolArguments
struct BasicArguments {
    @ToolArgument("String field")
    var text: String
    
    @ToolArgument("Integer field")
    var count: Int
    
    @ToolArgument("Double field")
    var price: Double
    
    @ToolArgument("Float field")
    var rating: Float
    
    @ToolArgument("Boolean field")
    var isActive: Bool
}

// Optional fields test
@ToolArguments
struct OptionalArguments {
    @ToolArgument("Required string")
    var required: String
    
    @ToolArgument("Optional string")
    var optional: String?
    
    @ToolArgument("Optional integer")
    var count: Int?
    
    @ToolArgument("Optional array")
    var tags: [String]?
}

// Array types test
@ToolArguments
struct ArrayArguments {
    @ToolArgument("String array")
    var tags: [String]
    
    @ToolArgument("Integer array")
    var numbers: [Int]
    
    @ToolArgument("Optional array")
    var optionalTags: [String]?
    
    @ToolArgument("Array of booleans")
    var flags: [Bool]
}

// Enum types test
@ToolArguments
struct EnumArguments {
    @ToolArgument("Simple enum")
    var status: Status
    
    @ToolArgument("Optional enum")
    var priority: Priority?
    
    @ToolArgument("Enum with explicit values", enum: ["draft", "published"])
    var state: State
    
    @ToolArgument("Integer with enum values", enum: [1, 2, 3, 4, 5])
    var rating: Int
    
    @ToolArgument("Optional integer with enum", enum: [10, 20, 30])
    var level: Int?
    
    enum Status: String, Decodable, ToolArgumentType, CaseIterable {
        case active
        case inactive
        case pending
    }
    
    enum Priority: String, Decodable, ToolArgumentType, CaseIterable {
        case low
        case medium
        case high
    }
    
    enum State: String, Decodable, ToolArgumentType, CaseIterable {
        case draft
        case published
        case archived
    }
}

// Nested enum types test
@ToolArguments
struct NestedArguments {
    @ToolArgument("Simple field")
    var id: String
    
    @ToolArgument("Nested enum field")
    var type: ItemType
    
    @ToolArgument("Optional nested enum")
    var category: Category?
    
    enum ItemType: String, Decodable, ToolArgumentType, CaseIterable {
        case product
        case service
    }
    
    enum Category: String, Decodable, ToolArgumentType, CaseIterable {
        case electronics
        case clothing
        case food
    }
}

// Special types test
@ToolArguments
struct SpecialArguments {
    @ToolArgument("Binary data")
    var image: Data
    
    @ToolArgument("Optional binary data")
    var thumbnail: Data?
    
    @ToolArgument("Email address", format: "email")
    var email: String
    
    @ToolArgument("URL", format: "uri")
    var website: String
    
    @ToolArgument("Custom format", format: "date-time")
    var timestamp: String
}

// Empty struct test
@ToolArguments
struct EmptyArguments {}

// Mixed properties test
@ToolArguments
struct MixedArguments {
    // Properties with @ToolArgument
    @ToolArgument("Included field")
    var included: String
    
    // Properties without @ToolArgument should be ignored
    var notIncluded: String
    
    @ToolArgument("Another included field")
    var alsoIncluded: Int
}

// MARK: - Basic Functionality Tests

@Test
func testBasicTypes() async throws {
    let schema = BasicArguments.argumentsSchema
    
    // Verify all properties are initialized
    #expect(schema["text"]?.description == "String field")
    #expect(schema["count"]?.description == "Integer field")
    #expect(schema["price"]?.description == "Double field")
    #expect(schema["rating"]?.description == "Float field")
    #expect(schema["isActive"]?.description == "Boolean field")
    
    // Verify JSON schema types
    let jsonSchema = BasicArguments.generateSchema()
    let properties = try #require(jsonSchema["properties"] as? [String: [String: any Sendable]])
    
    #expect(properties["text"]?["type"] as? String == "string")
    #expect(properties["count"]?["type"] as? String == "integer")
    #expect(properties["price"]?["type"] as? String == "number")
    #expect(properties["rating"]?["type"] as? String == "number")
    #expect(properties["isActive"]?["type"] as? String == "boolean")
    
    // All fields should be required
    let required = jsonSchema["required"] as? [String] ?? []
    #expect(required.sorted() == ["count", "isActive", "price", "rating", "text"])
}

@Test
func testOptionalFields() async throws {
    let jsonSchema = OptionalArguments.generateSchema()
    
    // Only required field should be in required array
    let required = jsonSchema["required"] as? [String] ?? []
    #expect(required == ["required"])
    
    // All fields should exist in properties
    let properties = try #require(jsonSchema["properties"] as? [String: [String: any Sendable]])
    #expect(properties.keys.sorted() == ["count", "optional", "required", "tags"])
}

// MARK: - Array and Collection Tests

@Test
func testArrayTypes() async throws {
    let jsonSchema = ArrayArguments.generateSchema()
    let properties = try #require(jsonSchema["properties"] as? [String: [String: any Sendable]])
    
    // Verify array types
    for key in ["tags", "numbers", "flags", "optionalTags"] {
        let prop = try #require(properties[key])
        #expect(prop["type"] as? String == "array")
    }
    
    // Verify item types
    #expect((properties["tags"]?["items"] as? [String: String])?["type"] == "string")
    #expect((properties["numbers"]?["items"] as? [String: String])?["type"] == "integer")
    #expect((properties["flags"]?["items"] as? [String: String])?["type"] == "boolean")
    
    // Verify required fields
    let required = jsonSchema["required"] as? [String] ?? []
    #expect(required.sorted() == ["flags", "numbers", "tags"])
}

// MARK: - Enum Tests

@Test
func testEnumTypes() async throws {
    let schema = EnumArguments.argumentsSchema
    
    // Check enum values
    if case .enum(let values, _) = schema["status"] {
        #expect(values as? [String] == ["active", "inactive", "pending"])
    } else {
        Issue.record("Expected status to be enum type")
    }
    
    if case .optional(let wrapped) = schema["priority"],
       case .enum(let values, _) = wrapped {
        #expect(values as? [String] == ["low", "medium", "high"])
    } else {
        Issue.record("Expected priority to be optional enum type")
    }
    
    if case .enum(let values, _) = schema["state"] {
        #expect(values as? [String] == ["draft", "published"])
    } else {
        Issue.record("Expected state to be enum type")
    }
    
    if case .enum(let values, _) = schema["rating"] {
        #expect(values as? [Int] == [1, 2, 3, 4, 5])
    } else {
        Issue.record("Expected rating to be enum type")
    }
    
    if case .optional(let wrapped) = schema["level"],
       case .enum(let values, _) = wrapped {
        #expect(values as? [Int] == [10, 20, 30])
    } else {
        Issue.record("Expected level to be optional enum type")
    }
    
    let jsonSchema = EnumArguments.generateSchema()
    let properties = try #require(jsonSchema["properties"] as? [String: [String: any Sendable]])
    
    // Verify all enums are string type
    #expect(properties["status"]?["type"] as? String == "string")
    #expect(properties["priority"]?["type"] as? String == "string")
    #expect(properties["state"]?["type"] as? String == "string")
    
    // Verify integer types with enum
    #expect(properties["rating"]?["type"] as? String == "integer")
    #expect(properties["level"]?["type"] as? String == "integer")
    
    // Verify enum values
    #expect(properties["rating"]?["enum"] as? [Int] == [1, 2, 3, 4, 5])
    #expect(properties["level"]?["enum"] as? [Int] == [10, 20, 30])
    
    // Verify required fields
    let required = jsonSchema["required"] as? [String] ?? []
    #expect(required.sorted() == ["rating", "state", "status"])
}

@Test
func testNestedEnumTypes() async throws {
    let schema = NestedArguments.argumentsSchema
    
    // Verify nested enum values
    if case .enum(let values, _) = schema["type"] {
        #expect(values as? [String] == ["product", "service"])
    } else {
        Issue.record("Expected type to be enum type")
    }
    
    let jsonSchema = NestedArguments.generateSchema()
    
    // Verify the generated type names are properly qualified
    #expect(jsonSchema["type"] as? String == "object")
    let properties = try #require(jsonSchema["properties"] as? [String: [String: any Sendable]])
    
    // All should be string type
    #expect(properties["id"]?["type"] as? String == "string")
    #expect(properties["type"]?["type"] as? String == "string")
    #expect(properties["category"]?["type"] as? String == "string")
}

// MARK: - Special Type Tests

@Test
func testDataAndFormatTypes() async throws {
    let schema = SpecialArguments.argumentsSchema
    
    // Data types should have byte format
    if case .string(_, let format) = schema["image"] {
        #expect(format == "byte")
    } else {
        Issue.record("Expected image to be string type")
    }
    
    if case .optional(let wrapped) = schema["thumbnail"],
       case .string(_, let format) = wrapped {
        #expect(format == "byte")
    } else {
        Issue.record("Expected thumbnail to be optional string type")
    }
    
    // Custom formats should be preserved
    if case .string(_, let format) = schema["email"] {
        #expect(format == "email")
    } else {
        Issue.record("Expected email to be string type")
    }
    
    if case .string(_, let format) = schema["website"] {
        #expect(format == "uri")
    } else {
        Issue.record("Expected website to be string type")
    }
    
    if case .string(_, let format) = schema["timestamp"] {
        #expect(format == "date-time")
    } else {
        Issue.record("Expected timestamp to be string type")
    }
    
    let jsonSchema = SpecialArguments.generateSchema()
    let properties = try #require(jsonSchema["properties"] as? [String: [String: any Sendable]])
    
    // Verify Data types become string with byte format
    #expect(properties["image"]?["type"] as? String == "string")
    #expect(properties["image"]?["format"] as? String == "byte")
    #expect(properties["thumbnail"]?["type"] as? String == "string")
    #expect(properties["thumbnail"]?["format"] as? String == "byte")
    
    // Verify custom formats
    #expect(properties["email"]?["format"] as? String == "email")
    #expect(properties["website"]?["format"] as? String == "uri")
    #expect(properties["timestamp"]?["format"] as? String == "date-time")
}

// MARK: - Edge Cases

@Test
func testEmptyStruct() async throws {
    let jsonSchema = EmptyArguments.generateSchema()
    
    #expect(jsonSchema["type"] as? String == "object")
    #expect((jsonSchema["properties"] as? [String: Any])?.isEmpty == true)
    #expect(jsonSchema["required"] == nil)
}

@Test
func testMixedProperties() async throws {
    let jsonSchema = MixedArguments.generateSchema()
    let properties = try #require(jsonSchema["properties"] as? [String: [String: any Sendable]])
    
    // Only properties with @ToolArgument should be included
    #expect(properties.keys.sorted() == ["alsoIncluded", "included"])
    #expect(properties["notIncluded"] == nil)
    
    // Required fields should only include those with @ToolArgument
    let required = jsonSchema["required"] as? [String] ?? []
    #expect(required.sorted() == ["alsoIncluded", "included"])
}
