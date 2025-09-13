import Foundation

// MARK: - Tool Argument Definition

/// Represents a tool argument with its schema properties
package struct ToolArgument<T: ToolArgumentType> {
    /// Description of the argument
    package let description: String
    
    /// Optional enum values
    package let `enum`: [any Sendable]?
    
    /// Optional format for string types (e.g., "byte" for base64 encoded data, "date-time" for dates)
    package let format: String?
    
    /// The JSON Schema type
    package var type: String {
        T.toolArgumentType
    }
    
    /// Whether this argument is optional
    package var isOptional: Bool {
        T.self is any ExpressibleByNilLiteral.Type
    }
    
    /// Creates a new tool argument
    /// - Parameters:
    ///   - description: Description of the argument
    ///   - enum: Optional enum values
    package init(description: String, enum: [any Sendable]? = nil) {
        self.description = description
        // Use provided enum values, or automatically get them from CaseIterable types
        self.enum = `enum` ?? T.enumValues
        self.format = nil
    }
    
    /// Creates a new tool argument with format
    /// - Parameters:
    ///   - description: Description of the argument
    ///   - enum: Optional enum values
    ///   - format: Optional format for string types
    package init(description: String, enum: [any Sendable]? = nil, format: String?) {
        self.description = description
        // Use provided enum values, or automatically get them from CaseIterable types
        self.enum = `enum` ?? T.enumValues
        self.format = format
    }
}

// MARK: - Specialized Initializers

// Protocol to identify types that have default formats
package protocol DefaultFormattedType {
    static var defaultFormat: String { get }
}

extension Data: DefaultFormattedType {
    package static var defaultFormat: String { "byte" }
}

extension Date: DefaultFormattedType {
    package static var defaultFormat: String { "date-time" }
}

extension URL: DefaultFormattedType {
    package static var defaultFormat: String { "uri" }
}

extension ToolArgument {
    /// Creates a new tool argument with automatic format detection
    /// - Parameter description: Description of the argument
    package init(description: String) where T: DefaultFormattedType {
        self.description = description
        self.enum = nil
        self.format = T.defaultFormat
    }
    
    /// Creates a new tool argument for optional Data type with base64 encoding
    /// - Parameter description: Description of the argument
    package init(description: String) where T == Data? {
        self.description = description
        self.enum = nil
        self.format = Data.defaultFormat
    }
    
    /// Creates a new tool argument for optional Date type with date-time format
    /// - Parameter description: Description of the argument
    package init(description: String) where T == Date? {
        self.description = description
        self.enum = nil
        self.format = Date.defaultFormat
    }
    
    /// Creates a new tool argument for optional URL type with uri format
    /// - Parameter description: Description of the argument
    package init(description: String) where T == URL? {
        self.description = description
        self.enum = nil
        self.format = URL.defaultFormat
    }
}

// MARK: - Internal Protocol

protocol ToolArgumentConvertible {
    func toPropertySchema() -> [String: any Sendable]
    var isOptional: Bool { get }
}

extension ToolArgument: ToolArgumentConvertible {
    func toPropertySchema() -> [String: any Sendable] {
        var schema: [String: any Sendable] = [
            "type": type,
            "description": description
        ]
        
        if let enumValues = self.enum {
            schema["enum"] = enumValues
        }
        
        if let format = self.format {
            schema["format"] = format
        }
        
        // Handle array types with items schema
        if type == "array", let arrayInfo = T.arrayElementInfo {
            var itemsSchema: [String: any Sendable] = ["type": arrayInfo.type]
            
            // If array element is an object, include its schema
            if arrayInfo.type == "object",
               let elementType = arrayInfo.elementType,
               let objectSchema = elementType.objectSchema {
                itemsSchema = objectSchema
            }
            
            schema["items"] = itemsSchema
        }
        
        // Handle object types with properties schema
        if type == "object", let objectSchema = T.objectSchema {
            if let properties = objectSchema["properties"] {
                schema["properties"] = properties
            }
            if let required = objectSchema["required"] {
                schema["required"] = required
            }
        }
        
        return schema
    }
}