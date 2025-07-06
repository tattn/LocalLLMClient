import Testing
import Foundation
@testable import LocalLLMClient
@testable import LocalLLMClientCore
import LocalLLMClientMacros
import LocalLLMClientTestUtilities

// MARK: - Integration Tests with Real Tool Examples

// MARK: Weather Tool Types

// GetWeatherTool demonstrates the @ToolArguments macro with enum support
@Tool("get_weather")
struct GetWeatherTool {
    let description = "Get the current weather in a given location"

    @ToolArguments
    struct Arguments {
        @ToolArgument("The city to get weather for")
        var city: String

        @ToolArgument("The state or country (optional)")
        var state: String?

        @ToolArgument("Temperature unit", enum: ["celsius", "fahrenheit"])
        var unit: Unit

        @ToolArgumentEnum
        enum Unit: String {
            case celsius
            case fahrenheit
        }
    }

    func call(arguments: Arguments) async throws -> ToolOutput {
        // Simulate weather API call
        let temp = arguments.unit == .celsius ? "22" : "72"
        let location = arguments.state != nil ? "\(arguments.city), \(arguments.state!)" : arguments.city
        
        return ToolOutput([
            "location": location,
            "temperature": temp,
            "unit": arguments.unit.rawValue,
            "condition": "sunny",
            "humidity": "45%"
        ])
    }
}

// MARK: Search Tool Types

// SearchToolExample demonstrates the @ToolArguments macro with optional and Data types
@Tool("search")
struct SearchToolExample {
    let description = "Search for content using text or image"

    @ToolArguments
    struct Arguments {
        @ToolArgument("Search query")
        var query: String

        @ToolArgument("Maximum number of results")
        var limit: Int

        @ToolArgument("Search type")
        var type: SearchType

        @ToolArgument("Filter by categories")
        var categories: [String]?

        @ToolArgument("Base64 encoded image for visual search")
        var image: Data?

        @ToolArgumentEnum
        enum SearchType: String {
            case text
            case image
            case hybrid
        }
    }

    func call(arguments: Arguments) async throws -> ToolOutput {
        // Simulate search results
        var results: [String: String] = [
            "query": arguments.query,
            "type": arguments.type.rawValue,
            "resultCount": String(min(arguments.limit, 10))
        ]
        
        if let categories = arguments.categories {
            results["categories"] = categories.joined(separator: ", ")
        }
        
        if arguments.image != nil {
            results["hasImage"] = "true"
        }
        
        return ToolOutput(results)
    }
}

// MARK: Calculator Tool Types

// CalculatorToolExample demonstrates the @ToolArguments macro with error handling
@Tool("calculator")
struct CalculatorToolExample {
    let description = "Perform basic arithmetic operations"

    @ToolArguments
    struct Arguments {
        @ToolArgument("First number")
        var a: Double

        @ToolArgument("Second number")
        var b: Double

        @ToolArgument("Operation to perform")
        var operation: Operation

        @ToolArgument("Number of decimal places (optional)")
        var precision: Int?
        
        @ToolArgumentEnum
        enum Operation: String {
            case add
            case subtract
            case multiply
            case divide
        }
    }

    func call(arguments: Arguments) async throws -> ToolOutput {
        let result: Double
        
        switch arguments.operation {
        case .add:
            result = arguments.a + arguments.b
        case .subtract:
            result = arguments.a - arguments.b
        case .multiply:
            result = arguments.a * arguments.b
        case .divide:
            guard arguments.b != 0 else {
                throw CalculatorToolExampleError.divisionByZero
            }
            result = arguments.a / arguments.b
        }
        
        let formattedResult: String
        if let precision = arguments.precision {
            formattedResult = String(format: "%.*f", precision, result)
        } else {
            formattedResult = String(result)
        }
        
        return ToolOutput([
            "result": formattedResult,
            "operation": arguments.operation.rawValue,
            "expression": "\(arguments.a) \(arguments.operation.rawValue) \(arguments.b)"
        ])
    }
    
    enum CalculatorToolExampleError: Error {
        case divisionByZero
        case invalidOperation
    }
}

// MARK: User Management Tool Types (Nested struct example)

@Tool("user_management")
struct UserManagementTool {
    let description = "Manage user accounts and profiles"

    @ToolArguments
    struct Arguments {
        @ToolArgument("User ID")
        var userId: String

        @ToolArgument("Action to perform", enum: ["create", "update", "delete", "get"])
        var action: String

        @ToolArgument("User profile data (for create/update operations)")
        var profile: UserProfile?

        @ToolArgument("Update specific fields only")
        var updateFields: [String]?

        @ToolArguments
        struct UserProfile {
            @ToolArgument("User's full name")
            var name: String
            @ToolArgument("User's email address")
            var email: String
            @ToolArgument("User's age")
            var age: Int?
            @ToolArgument("User's address")
            var address: Address?
            @ToolArgument("User's preferences")
            var preferences: Preferences?

            @ToolArguments
            struct Address {
                @ToolArgument("Street address")
                var street: String
                @ToolArgument("City name")
                var city: String
                @ToolArgument("Country name")
                var country: String
                @ToolArgument("Postal code")
                var postalCode: String?
            }

            @ToolArguments
            struct Preferences {
                @ToolArgument("Preferred language")
                var language: String
                @ToolArgument("Notification settings")
                var notifications: NotificationSettings
                @ToolArgument("UI theme")
                var theme: String?

                @ToolArguments
                struct NotificationSettings {
                    @ToolArgument("Email notifications enabled")
                    var email: Bool
                    @ToolArgument("Push notifications enabled")
                    var push: Bool
                    @ToolArgument("SMS notifications enabled")
                    var sms: Bool?
                }
            }
        }
    }

    func call(arguments: Arguments) async throws -> ToolOutput {
        var result: [String: String] = [
            "userId": arguments.userId,
            "action": arguments.action,
            "status": "success"
        ]

        if let profile = arguments.profile {
            result["userName"] = profile.name
            result["userEmail"] = profile.email

            if let age = profile.age {
                result["userAge"] = String(age)
            }

            if let address = profile.address {
                result["userCity"] = address.city
                result["userCountry"] = address.country
            }

            if let prefs = profile.preferences {
                result["userLanguage"] = prefs.language
                result["emailNotifications"] = String(prefs.notifications.email)
                result["pushNotifications"] = String(prefs.notifications.push)
            }
        }

        if let fields = arguments.updateFields {
            result["updatedFields"] = fields.joined(separator: ", ")
        }

        return ToolOutput(result)
    }
}

// MARK: - Tests

@Test
func testWeatherToolIntegration() async throws {
    // Test the tool schema generation
    let tool = GetWeatherTool()
    let schema = GetWeatherTool.Arguments.generateSchema()
    
    #expect(schema["type"] as? String == "object")
    
    let properties = try #require(schema["properties"] as? [String: [String: any Sendable]])
    
    // Verify all properties exist
    #expect(properties.keys.sorted() == ["city", "state", "unit"])
    
    // Verify unit enum values
    let unitProp = try #require(properties["unit"])
    #expect(unitProp["enum"] as? [String] == ["celsius", "fahrenheit"])
    
    // Test actual tool execution
    let result = try await tool.call(arguments: GetWeatherTool.Arguments(
        city: "Tokyo",
        state: "Japan",
        unit: .celsius
    ))
    
    #expect(result.data["temperature"] as? String == "22")
    #expect(result.data["location"] as? String == "Tokyo, Japan")
    #expect(result.data["unit"] as? String == "celsius")
}

@Test
func testSearchToolIntegration() async throws {
    // Test schema generation
    let tool = SearchToolExample()
    let schema = SearchToolExample.Arguments.generateSchema()
    let properties = try #require(schema["properties"] as? [String: [String: any Sendable]])
    
    // Verify search type enum
    let typeProp = try #require(properties["type"])
    #expect(typeProp["enum"] as? [String] == ["text", "image", "hybrid"])
    
    // Verify Data type format
    let imageProp = try #require(properties["image"])
    #expect(imageProp["format"] as? String == "byte")
    
    // Test tool execution
    let imageData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header
    let result = try await tool.call(arguments: SearchToolExample.Arguments(
        query: "swift programming",
        limit: 5,
        type: .hybrid,
        categories: ["tutorials", "documentation"],
        image: imageData
    ))
    
    #expect(result.data["resultCount"] as? String == "5")
    #expect(result.data["type"] as? String == "hybrid")
    #expect(result.data["categories"] as? String == "tutorials, documentation")
    #expect(result.data["hasImage"] as? String == "true")
}

@Test
func testCalculatorToolIntegration() async throws {
    // Test schema
    let tool = CalculatorToolExample()
    let schema = CalculatorToolExample.Arguments.generateSchema()
    let properties = try #require(schema["properties"] as? [String: [String: any Sendable]])
    
    // Verify operation enum
    let opProp = try #require(properties["operation"])
    #expect(opProp["enum"] as? [String] == ["add", "subtract", "multiply", "divide"])
    
    // Test execution
    let result = try await tool.call(arguments: CalculatorToolExample.Arguments(
        a: 10.5,
        b: 2.5,
        operation: .multiply,
        precision: 2
    ))
    
    #expect(result.data["result"] as? String == "26.25")
    #expect(result.data["expression"] as? String == "10.5 multiply 2.5")
}

@Test
func testUserManagementToolWithNestedStructs() async throws {
    // Test schema generation with nested structs
    let tool = UserManagementTool()
    let schema = UserManagementTool.Arguments.generateSchema()
    
    #expect(schema["type"] as? String == "object")
    
    let properties = try #require(schema["properties"] as? [String: [String: any Sendable]])
    
    // Verify all top-level properties exist
    #expect(properties.keys.sorted() == ["action", "profile", "updateFields", "userId"])
    
    // Verify action enum
    let actionProp = try #require(properties["action"])
    #expect(actionProp["enum"] as? [String] == ["create", "update", "delete", "get"])
    
    // Verify profile is an object type
    let profileProp = try #require(properties["profile"])
    #expect(profileProp["type"] as? String == "object")
    
    // Test with full nested data
    let address = UserManagementTool.Arguments.UserProfile.Address(
        street: "123 Main St",
        city: "Tokyo",
        country: "Japan",
        postalCode: "100-0001"
    )
    
    let notifications = UserManagementTool.Arguments.UserProfile.Preferences.NotificationSettings(
        email: true,
        push: false,
        sms: true
    )
    
    let preferences = UserManagementTool.Arguments.UserProfile.Preferences(
        language: "ja",
        notifications: notifications,
        theme: "dark"
    )
    
    let profile = UserManagementTool.Arguments.UserProfile(
        name: "Test User",
        email: "test@example.com",
        age: 30,
        address: address,
        preferences: preferences
    )
    
    // Test tool execution
    let result = try await tool.call(arguments: UserManagementTool.Arguments(
        userId: "user123",
        action: "create",
        profile: profile,
        updateFields: nil
    ))
    
    // Verify results
    #expect(result.data["userId"] as? String == "user123")
    #expect(result.data["action"] as? String == "create")
    #expect(result.data["status"] as? String == "success")
    #expect(result.data["userName"] as? String == "Test User")
    #expect(result.data["userEmail"] as? String == "test@example.com")
    #expect(result.data["userAge"] as? String == "30")
    #expect(result.data["userCity"] as? String == "Tokyo")
    #expect(result.data["userCountry"] as? String == "Japan")
    #expect(result.data["userLanguage"] as? String == "ja")
    #expect(result.data["emailNotifications"] as? String == "true")
    #expect(result.data["pushNotifications"] as? String == "false")
}

@Test
func testUserManagementToolPartialData() async throws {
    let tool = UserManagementTool()
    
    // Test with minimal profile data
    let profile = UserManagementTool.Arguments.UserProfile(
        name: "Simple User",
        email: "simple@example.com",
        age: nil,
        address: nil,
        preferences: nil
    )
    
    let result = try await tool.call(arguments: UserManagementTool.Arguments(
        userId: "user456",
        action: "update",
        profile: profile,
        updateFields: ["name", "email"]
    ))
    
    // Verify results
    #expect(result.data["userName"] as? String == "Simple User")
    #expect(result.data["userEmail"] as? String == "simple@example.com")
    #expect(result.data["updatedFields"] as? String == "name, email")
    #expect(result.data["userAge"] == nil)
    #expect(result.data["userCity"] == nil)
}

@Test
func testCommonTestToolsIntegration() async throws {
    // Test that macro-generated tools and CommonTestTools both work well
    let macroWeatherTool = GetWeatherTool()
    let macroSearchTool = SearchToolExample()
    let macroCalculatorTool = CalculatorToolExample()
    let macroUserTool = UserManagementTool()
    
    // Test that all tools generate proper schemas
    let tools = [
        AnyLLMTool(macroWeatherTool),
        AnyLLMTool(macroSearchTool),
        AnyLLMTool(macroCalculatorTool),
        AnyLLMTool(macroUserTool)
    ]
    
    for tool in tools {
        let schema = tool.toOAICompatJSON()
        #expect(schema["type"] as? String == "function")
        
        let function = schema["function"] as? [String: Any]
        #expect(function?["name"] as? String != nil)
        #expect(function?["description"] as? String != nil)
        
        let parameters = function?["parameters"] as? [String: Any]
        #expect(parameters?["type"] as? String == "object")
        #expect(parameters?["properties"] as? [String: Any] != nil)
    }
    
    // Test tool execution with macro examples
    let weatherResult = try await macroWeatherTool.call(
        arguments: GetWeatherTool.Arguments(city: "London", state: nil, unit: .celsius)
    )
    #expect(weatherResult.data["location"] as? String == "London")
    
    let calcResult = try await macroCalculatorTool.call(
        arguments: CalculatorToolExample.Arguments(a: 100, b: 25, operation: .divide, precision: nil)
    )
    #expect(calcResult.data["result"] as? String == "4.0")
    
    let searchResult = try await macroSearchTool.call(
        arguments: SearchToolExample.Arguments(query: "LocalLLMClient", limit: 2, type: .text, categories: nil, image: nil)
    )
    #expect(searchResult.data["resultCount"] as? String == "2")
}
