import Foundation
import LocalLLMClientCore
import LocalLLMClientMacros
import LocalLLMClientUtility

/// Test weather tool that tracks invocations
public final class TestWeatherTool: LLMTool {
    public let name = "get_weather"
    public let description = "Get the current weather for a location"
    
    // Track invocation count and arguments
    private let _invocationCount = Locked(0)
    private let _lastArguments = Locked<Arguments?>(nil)
    
    public var invocationCount: Int {
        _invocationCount.withLock { $0 }
    }
    
    public var lastArguments: Arguments? {
        _lastArguments.withLock { $0 }
    }
    
    @ToolArguments
    public struct Arguments: Sendable {
        @ToolArgument("The city to get weather for")
        public var location: String
        
        @ToolArgument("Temperature unit")
        public var unit: Unit?
        
        @ToolArgumentEnum
        public enum Unit: String, Sendable {
            case celsius
            case fahrenheit
        }
    }
    
    public init() {}
    
    public func call(arguments: Arguments) async throws -> ToolOutput {
        _invocationCount.withLock { $0 += 1 }
        _lastArguments.withLock { $0 = arguments }
        
        // Mock weather data
        let temp = arguments.unit == .fahrenheit ? 72 : 22
        return ToolOutput(data: [
            "location": arguments.location,
            "temperature": temp,
            "unit": arguments.unit?.rawValue ?? "celsius",
            "conditions": "sunny"
        ])
    }
    
    public func reset() {
        _invocationCount.withLock { $0 = 0 }
        _lastArguments.withLock { $0 = nil }
    }
}

/// Test calculator tool that tracks invocations
public final class TestCalculatorTool: LLMTool {
    public let name = "calculate"
    public let description = "Perform basic arithmetic calculations"
    
    // Track invocation count and arguments
    private let _invocationCount = Locked(0)
    private let _lastArguments = Locked<Arguments?>(nil)
    
    public var invocationCount: Int {
        _invocationCount.withLock { $0 }
    }
    
    public var lastArguments: Arguments? {
        _lastArguments.withLock { $0 }
    }
    
    @ToolArguments
    public struct Arguments: Sendable {
        @ToolArgument("The mathematical expression to evaluate")
        public var expression: String
    }
    
    public init() {}
    
    public func call(arguments: Arguments) async throws -> ToolOutput {
        _invocationCount.withLock { $0 += 1 }
        _lastArguments.withLock { $0 = arguments }
        
        // Simple mock implementation
        let result: Double
        switch arguments.expression {
        case "2 + 2":
            result = 4
        case "10 * 5":
            result = 50
        case "100 / 4":
            result = 25
        case "1 + 2":
            result = 3
        default:
            // Try to parse simple expressions
            if arguments.expression.contains("+") {
                let parts = arguments.expression.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2, let a = Double(parts[0]), let b = Double(parts[1]) {
                    result = a + b
                } else {
                    result = 0
                }
            } else {
                result = 0
            }
        }
        
        return ToolOutput(data: [
            "expression": arguments.expression,
            "result": result
        ])
    }
    
    public func reset() {
        _invocationCount.withLock { $0 = 0 }
        _lastArguments.withLock { $0 = nil }
    }
}
