import Foundation
import LocalLLMClient
import LocalLLMClientMacros

// MARK: - Weather Tool

@Tool("get_weather")
struct WeatherTool {
    let description = "Get the current weather for a location"
    
    @ToolArguments
    struct Arguments {
        @ToolArgument("The city to get weather for")
        var location: String
        
        @ToolArgument("Temperature unit (celsius or fahrenheit)")
        var unit: Unit?
        
        @ToolArgumentEnum
        enum Unit: String {
            case celsius
            case fahrenheit
        }
    }
    
    func call(arguments: Arguments) async throws -> ToolOutput {
        // Mock weather data
        let weather = (temp: 20, conditions: "Sunny")

        let tempInUnit: Int
        if arguments.unit == .fahrenheit {
            tempInUnit = Int(Double(weather.temp) * 9/5 + 32)
        } else {
            tempInUnit = weather.temp
        }
        
        return ToolOutput(data: [
            "location": arguments.location,
            "temperature": tempInUnit,
            "unit": arguments.unit?.rawValue ?? "celsius",
            "conditions": weather.conditions,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }
}

// MARK: - Calculator Tool

@Tool("calculate")
struct CalculatorTool {
    let description = "Perform basic mathematical calculations"
    
    @ToolArguments
    struct Arguments {
        @ToolArgument("Mathematical expression to evaluate (e.g., '2 + 2', '10 * 5')")
        var expression: String
    }
    
    func call(arguments: Arguments) async throws -> ToolOutput {
        let expression = NSExpression(format: arguments.expression)
        
        do {
            guard let result = expression.expressionValue(with: nil, context: nil) else {
                throw CalculatorError.invalidExpression
            }
            
            return ToolOutput(data: [
                "expression": arguments.expression,
                "result": "\(result)"
            ])
        } catch {
            return ToolOutput(data: [
                "expression": arguments.expression,
                "error": "Failed to calculate: \(error.localizedDescription)"
            ])
        }
    }
    
    enum CalculatorError: Error {
        case invalidExpression
    }
}

// MARK: - Date/Time Tool

@Tool("get_current_time")
struct DateTimeTool {
    let description = "Get the current date and time in a specific timezone"
    
    @ToolArguments
    struct Arguments {
        @ToolArgument("Timezone identifier (e.g., 'Asia/Tokyo', 'America/New_York')")
        var timezone: String?
    }
    
    func call(arguments: Arguments) async throws -> ToolOutput {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .long
        
        if let timezoneId = arguments.timezone,
           let timezone = TimeZone(identifier: timezoneId) {
            formatter.timeZone = timezone
        }
        
        let now = Date()
        let formattedDate = formatter.string(from: now)
        
        return ToolOutput(data: [
            "datetime": formattedDate,
            "timezone": formatter.timeZone.identifier
        ])
    }
}

// MARK: - Random Number Generator Tool

@Tool("generate_random_number")
struct RandomNumberTool {
    let description = "Generate a random number within a specified range"
    
    @ToolArguments
    struct Arguments {
        @ToolArgument("Minimum value (inclusive)")
        var min: Int
        
        @ToolArgument("Maximum value (inclusive)")
        var max: Int
    }
    
    func call(arguments: Arguments) async throws -> ToolOutput {
        guard arguments.min <= arguments.max else {
            return ToolOutput(data: [
                "error": "Minimum value must be less than or equal to maximum value",
                "min": arguments.min,
                "max": arguments.max
            ])
        }
        
        let randomNumber = Int.random(in: arguments.min...arguments.max)
        
        return ToolOutput(data: [
            "value": randomNumber,
            "min": arguments.min,
            "max": arguments.max
        ])
    }
}
