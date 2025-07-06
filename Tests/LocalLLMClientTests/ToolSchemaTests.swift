import Testing
import Foundation
@testable import LocalLLMClient
import LocalLLMClientMacros

// Test structs for schema generation tests
@ToolArguments
struct TestSchema {
    @ToolArgument("A required string field")
    var requiredString: String
    
    @ToolArgument("An optional string field")
    var optionalString: String?
    
    @ToolArgument("A required number field")
    var requiredNumber: Double
    
    @ToolArgument("An optional enum field", enum: ["option1", "option2"])
    var optionalEnum: String?
}

@Test
func verifyAutomaticRequiredFieldDetection() async throws {
    let schema = TestSchema.generateSchema()
    
    // Verify that only non-optional fields are in required array
    let required = schema["required"] as? [String] ?? []
    #expect(required.sorted() == ["requiredNumber", "requiredString"])
}

@ToolArguments
struct SimpleSchema {
    @ToolArgument("The name")
    var name: String
    
    @ToolArgument("The age in years")
    var age: Int
    
    @ToolArgument("Whether active")
    var active: Bool
}

@Test
func basicToolSchemaGeneration() async throws {
    let schema = SimpleSchema.generateSchema()
    
    #expect(schema["type"] as? String == "object")
    
    let properties = try #require(schema["properties"] as? [String: [String: any Sendable]])
    #expect(properties.count == 3)
    
    // Check name property
    let nameProp = try #require(properties["name"])
    #expect(nameProp["type"] as? String == "string")
    #expect(nameProp["description"] as? String == "The name")
    
    // Check age property
    let ageProp = try #require(properties["age"])
    #expect(ageProp["type"] as? String == "integer")
    #expect(ageProp["description"] as? String == "The age in years")
    
    // Check active property
    let activeProp = try #require(properties["active"])
    #expect(activeProp["type"] as? String == "boolean")
    #expect(activeProp["description"] as? String == "Whether active")
    
    // All fields should be required
    let required = schema["required"] as? [String] ?? []
    #expect(required.sorted() == ["active", "age", "name"])
}

@ToolArgumentEnum
enum Status: String {
    case active
    case inactive
    case pending
}

@ToolArguments
struct EnumSchema {
    @ToolArgument("Current status")
    var status: Status
    
    @ToolArgument("Optional priority", enum: ["low", "medium", "high"])
    var priority: String?
    
    @ToolArgument("Number with constraints", enum: [1, 2, 3, 4, 5])
    var level: Int
}

@Test
func enumArgumentSchemaGeneration() async throws {
    let schema = EnumSchema.generateSchema()
    let properties = try #require(schema["properties"] as? [String: [String: any Sendable]])
    
    // Status should have enum values from CaseIterable
    let statusProp = try #require(properties["status"])
    #expect(statusProp["type"] as? String == "string")
    #expect(statusProp["enum"] as? [String] == ["active", "inactive", "pending"])
    
    // Priority should have explicit enum values
    let priorityProp = try #require(properties["priority"])
    #expect(priorityProp["type"] as? String == "string")
    #expect(priorityProp["enum"] as? [String] == ["low", "medium", "high"])
    
    // Level should be integer with enum values
    let levelProp = try #require(properties["level"])
    #expect(levelProp["type"] as? String == "integer")
    #expect(levelProp["enum"] as? [Int] == [1, 2, 3, 4, 5])
    
    // Check required fields
    let required = schema["required"] as? [String] ?? []
    #expect(required.sorted() == ["level", "status"])
}

@ToolArguments
struct NumericSchema {
    @ToolArgument("Integer value")
    var intValue: Int
    
    @ToolArgument("Double value")
    var doubleValue: Double
    
    @ToolArgument("Float value")
    var floatValue: Float
    
    @ToolArgument("Optional number")
    var optionalNumber: Double?
}

@Test
func numericTypesToolSchema() async throws {
    
    let schema = NumericSchema.generateSchema()
    let properties = try #require(schema["properties"] as? [String: [String: any Sendable]])
    
    // Check integer type
    let intProp = try #require(properties["intValue"])
    #expect(intProp["type"] as? String == "integer")
    
    // Check double type
    let doubleProp = try #require(properties["doubleValue"])
    #expect(doubleProp["type"] as? String == "number")
    
    // Check float type
    let floatProp = try #require(properties["floatValue"])
    #expect(floatProp["type"] as? String == "number")
    
    // Check optional number
    let optionalProp = try #require(properties["optionalNumber"])
    #expect(optionalProp["type"] as? String == "number")
    
    // Check required fields
    let required = schema["required"] as? [String] ?? []
    #expect(required.sorted() == ["doubleValue", "floatValue", "intValue"])
}

@ToolArguments
struct EmptySchema {}

@Test
func emptySchemaGeneration() async throws {
    let schema = EmptySchema.generateSchema()
    
    #expect(schema["type"] as? String == "object")
    #expect((schema["properties"] as? [String: Any])?.isEmpty == true)
    #expect(schema["required"] == nil)
}

@ToolArguments
struct ArraySchema {
    @ToolArgument("List of strings")
    var tags: [String]
    
    @ToolArgument("List of numbers")
    var scores: [Double]
    
    @ToolArgument("Optional array")
    var optionalItems: [Int]?
}

@Test
func arrayTypesToolSchema() async throws {
    let schema = ArraySchema.generateSchema()
    let properties = try #require(schema["properties"] as? [String: [String: any Sendable]])
    
    // Check tags array
    let tagsProp = try #require(properties["tags"])
    #expect(tagsProp["type"] as? String == "array")
    let tagsItems = try #require(tagsProp["items"] as? [String: String])
    #expect(tagsItems["type"] == "string")
    
    // Check scores array
    let scoresProp = try #require(properties["scores"])
    #expect(scoresProp["type"] as? String == "array")
    let scoresItems = try #require(scoresProp["items"] as? [String: String])
    #expect(scoresItems["type"] == "number")
    
    // Check optional array
    let optionalProp = try #require(properties["optionalItems"])
    #expect(optionalProp["type"] as? String == "array")
    
    // Check required fields
    let required = schema["required"] as? [String] ?? []
    #expect(required.sorted() == ["scores", "tags"])
}

@ToolArguments
struct UserInfo {
    @ToolArgument("User's name")
    var name: String
    
    @ToolArgument("User's email")
    var email: String
}

@ToolArguments
struct Settings {
    @ToolArgument("Theme preference")
    var theme: String
    
    @ToolArgument("Notifications enabled")
    var notificationsEnabled: Bool
}

@ToolArguments
struct NestedSchema {
    @ToolArgument("User information")
    var user: UserInfo
    
    @ToolArgument("Optional settings")
    var settings: Settings?
}

@Test
func nestedObjectToolSchema() async throws {
    let schema = NestedSchema.generateSchema()
    let properties = try #require(schema["properties"] as? [String: [String: any Sendable]])
    
    // Check user property
    let userProp = try #require(properties["user"])
    #expect(userProp["type"] as? String == "object")
    #expect(userProp["description"] as? String == "User information")
    
    // User should have its own properties
    let userProperties = try #require(userProp["properties"] as? [String: [String: any Sendable]])
    #expect(userProperties.count == 2)
    #expect(userProperties["name"]?["type"] as? String == "string")
    #expect(userProperties["email"]?["type"] as? String == "string")
    
    // Check settings property
    let settingsProp = try #require(properties["settings"])
    #expect(settingsProp["type"] as? String == "object")
    
    // Check required fields
    let required = schema["required"] as? [String] ?? []
    #expect(required == ["user"])
}

@ToolArguments
struct DataSchema {
    @ToolArgument("Binary data")
    var imageData: Data
    
    @ToolArgument("Email address", format: "email")
    var email: String
    
    @ToolArgument("URL", format: "uri")
    var website: String
    
    @ToolArgument("Date time", format: "date-time")
    var timestamp: String
}

@Test
func dataTypeWithFormat() async throws {
    
    let schema = DataSchema.generateSchema()
    let properties = try #require(schema["properties"] as? [String: [String: any Sendable]])
    
    // Data type should be string with byte format
    let dataProp = try #require(properties["imageData"])
    #expect(dataProp["type"] as? String == "string")
    #expect(dataProp["format"] as? String == "byte")
    
    // Email should have email format
    let emailProp = try #require(properties["email"])
    #expect(emailProp["type"] as? String == "string")
    #expect(emailProp["format"] as? String == "email")
    
    // Website should have uri format
    let websiteProp = try #require(properties["website"])
    #expect(websiteProp["type"] as? String == "string")
    #expect(websiteProp["format"] as? String == "uri")
    
    // Timestamp should have date-time format
    let timestampProp = try #require(properties["timestamp"])
    #expect(timestampProp["type"] as? String == "string")
    #expect(timestampProp["format"] as? String == "date-time")
}