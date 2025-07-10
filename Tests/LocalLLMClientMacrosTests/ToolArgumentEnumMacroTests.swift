import Testing
import Foundation
@testable import LocalLLMClientCore
import LocalLLMClientMacros

// MARK: - Test Types

// Basic enum with String raw value
@ToolArgumentEnum
enum TestStatus: String {
    case active
    case inactive
    case pending
}

// Enum with Int raw value
@ToolArgumentEnum
enum TestPriority: Int {
    case low = 1
    case medium = 2
    case high = 3
}

// Enum without explicit CaseIterable
@ToolArgumentEnum
enum TestCategory: String {
    case electronics
    case clothing
    case food
    case home
}

// Nested enum
struct TestProduct {
    @ToolArgumentEnum
    enum ProductType: String {
        case physical
        case digital
        case service
    }
}

// Test arguments with nested enums
@ToolArguments
struct TestArguments {
    @ToolArgument("Status of the item")
    var status: Status
    
    @ToolArgument("Priority level")
    var priority: Priority?
    
    @ToolArgument("Categories")
    var categories: [Category]
    
    @ToolArgumentEnum
    enum Status: String {
        case active
        case inactive
        case pending
    }
    
    @ToolArgumentEnum
    enum Priority: Int {
        case low = 1
        case medium = 2
        case high = 3
    }
    
    @ToolArgumentEnum
    enum Category: String {
        case electronics
        case clothing
        case food
        case home
    }
}

// MARK: - Tests

@Test
func testBasicEnumConformance() async throws {
    // Test that TestStatus conforms to required protocols
    let _: any Decodable.Type = TestStatus.self
    let _: any ToolArgumentType.Type = TestStatus.self
    let _: any CaseIterable.Type = TestStatus.self
    
    // Test Decodable
    let json = "\"active\""
    let data = json.data(using: .utf8)!
    let status = try JSONDecoder().decode(TestStatus.self, from: data)
    #expect(status == .active)
    
    // Test ToolArgumentType
    #expect(TestStatus.toolArgumentType == "string")
    #expect(TestStatus.enumValues as? [String] == ["active", "inactive", "pending"])
    
    // Test CaseIterable
    #expect(TestStatus.allCases.count == 3)
    #expect(TestStatus.allCases == [.active, .inactive, .pending])
}

@Test
func testIntEnumConformance() async throws {
    // Test conformances
    let _: any Decodable.Type = TestPriority.self
    let _: any ToolArgumentType.Type = TestPriority.self
    let _: any CaseIterable.Type = TestPriority.self
    
    // Test Decodable
    let json = "2"
    let data = json.data(using: .utf8)!
    let priority = try JSONDecoder().decode(TestPriority.self, from: data)
    #expect(priority == .medium)
    
    // Test ToolArgumentType
    #expect(TestPriority.toolArgumentType == "integer")
    #expect(TestPriority.enumValues as? [Int] == [1, 2, 3])
    
    // Test CaseIterable
    #expect(TestPriority.allCases.count == 3)
    #expect(TestPriority.allCases == [.low, .medium, .high])
}

@Test
func testCategoryEnum() async throws {
    // Test conformances
    let _: any Decodable.Type = TestCategory.self
    let _: any ToolArgumentType.Type = TestCategory.self
    let _: any CaseIterable.Type = TestCategory.self
    
    // Test functionality
    #expect(TestCategory.toolArgumentType == "string")
    #expect(TestCategory.enumValues as? [String] == ["electronics", "clothing", "food", "home"])
    #expect(TestCategory.allCases.count == 4)
}

@Test
func testNestedEnum() async throws {
    // Test conformances
    let _: any Decodable.Type = TestProduct.ProductType.self
    let _: any ToolArgumentType.Type = TestProduct.ProductType.self
    let _: any CaseIterable.Type = TestProduct.ProductType.self
    
    // Test functionality
    #expect(TestProduct.ProductType.toolArgumentType == "string")
    #expect(TestProduct.ProductType.enumValues as? [String] == ["physical", "digital", "service"])
    #expect(TestProduct.ProductType.allCases.count == 3)
}

@Test
func testEnumInToolArguments() async throws {
    // Test that enums with @ToolArgumentEnum work properly in @ToolArguments
    let jsonSchema = TestArguments.generateSchema()
    let properties = try #require(jsonSchema["properties"] as? [String: [String: any Sendable]])
    
    // Check status enum
    let statusProp = try #require(properties["status"])
    #expect(statusProp["type"] as? String == "string")
    #expect(statusProp["enum"] as? [String] == ["active", "inactive", "pending"])
    
    // Check priority enum
    let priorityProp = try #require(properties["priority"])
    #expect(priorityProp["type"] as? String == "integer")
    #expect(priorityProp["enum"] as? [Int] == [1, 2, 3])
    
    // Check categories array
    let categoriesProp = try #require(properties["categories"])
    #expect(categoriesProp["type"] as? String == "array")
    let itemsSchema = try #require(categoriesProp["items"] as? [String: any Sendable])
    #expect(itemsSchema["type"] as? String == "string")
}
