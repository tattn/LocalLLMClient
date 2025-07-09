import Foundation

/// Protocol for types that can generate a tool argument schema
public protocol ToolSchemaGeneratable {
    /// The schema describing the arguments for this type
    static var argumentsSchema: LLMToolArgumentsSchema { get }
}

extension ToolSchemaGeneratable {
    /// Generates a JSON Schema from this type's arguments schema
    public static func generateSchema() -> [String: any Sendable] {
        generateToolSchema(from: argumentsSchema)
    }
}

/// Protocol for object types that can be used as tool arguments
public protocol ToolArgumentObject: ToolArgumentType, ToolSchemaGeneratable {}

// Object type conformance
extension ToolArgumentObject {
    public static var toolArgumentType: String { "object" }
    public static var objectSchema: [String: any Sendable]? {
        generateToolSchema(from: Self.argumentsSchema)
    }
}

/// Typealias for tool argument schema dictionary
public typealias LLMToolArgumentsSchema = [String: LLMToolArgumentType]

/// Enum representing different types of tool arguments
public indirect enum LLMToolArgumentType {
    case string(description: String, format: String? = nil)
    case integer(description: String)
    case number(description: String)
    case boolean(description: String)
    case array(of: LLMToolArgumentType, description: String)
    case object(_ type: any ToolArgumentObject.Type, description: String)
    case `enum`(values: [any Sendable], description: String)
    case optional(_ wrapped: LLMToolArgumentType)
    
    /// The description for this argument type
    public var description: String {
        switch self {
        case .string(let description, _), .integer(let description), .number(let description),
             .boolean(let description), .array(_, let description), .object(_, let description),
             .enum(_, let description):
            return description
        case .optional(let wrapped):
            return wrapped.description
        }
    }
    
    /// Type-specific sub-types for pattern matching in tests
    package typealias StringType = (description: String, format: String?)
    package typealias EnumType = (values: [any Sendable], description: String)
    
    /// Converts to ToolArgument for schema generation
    var asToolArgument: any ToolArgumentConvertible {
        switch self {
        case .string(let description, let format):
            return createStringToolArgument(description: description, format: format)
        case .integer(let description):
            return ToolArgument<Int>(description: description)
        case .number(let description):
            return ToolArgument<Double>(description: description)
        case .boolean(let description):
            return ToolArgument<Bool>(description: description)
        case .array(let elementType, let description):
            return createArrayToolArgument(elementType: elementType, description: description)
        case .object(let type, let description):
            return createObjectToolArgument(type: type, description: description)
        case .enum(let values, let description):
            return createEnumToolArgument(values: values, description: description)
        case .optional(let wrapped):
            return createOptionalToolArgument(wrapped: wrapped)
        }
    }
    
    private func createStringToolArgument(description: String, format: String?) -> any ToolArgumentConvertible {
        if let format = format {
            return ToolArgument<String>(description: description, format: format)
        } else {
            return ToolArgument<String>(description: description)
        }
    }
    
    private func createEnumToolArgument(values: [any Sendable], description: String) -> any ToolArgumentConvertible {
        // Determine the type based on the first value
        let isIntegerEnum = values.first is Int
        
        if isIntegerEnum {
            return ToolArgument<Int>(description: description, enum: values)
        } else {
            return ToolArgument<String>(description: description, enum: values)
        }
    }
    
    private func createArrayToolArgument(elementType: LLMToolArgumentType, description: String) -> any ToolArgumentConvertible {
        // Create a specialized tool argument that properly handles array types with their element types
        switch elementType {
        case .string(let elementDescription, let format):
            // For string arrays with format, create a custom handler to preserve element format
            if let format = format {
                return createArrayWithFormatToolArgument(
                    elementType: "string",
                    elementDescription: elementDescription,
                    format: format,
                    description: description
                )
            } else {
                return ToolArgument<[String]>(description: description)
            }
        case .integer:
            return ToolArgument<[Int]>(description: description)
        case .number:
            return ToolArgument<[Double]>(description: description)
        case .boolean:
            return ToolArgument<[Bool]>(description: description)
        case .array(let nestedElementType, _):
            // For nested arrays, we need to create a custom handler
            return createNestedArrayToolArgument(
                nestedElementType: nestedElementType,
                description: description
            )
        case .object(let type, _):
            // For arrays of objects, create a custom handler that preserves object schema
            return createArrayOfObjectsToolArgument(
                objectType: type,
                description: description
            )
        case .enum(let values, let elementDescription):
            // For enum arrays, create a custom handler to preserve element enum values
            return createArrayOfEnumsToolArgument(
                values: values,
                elementDescription: elementDescription,
                description: description
            )
        case .optional(let wrapped):
            // For arrays of optionals, recursively handle the wrapped type
            return createArrayOfOptionalsToolArgument(
                wrappedType: wrapped,
                description: description
            )
        }
    }
    
    private func createArrayWithFormatToolArgument(elementType: String, elementDescription: String, format: String, description: String) -> any ToolArgumentConvertible {
        // Handle arrays with formatted elements (e.g., array of base64 strings, timestamps)
        struct ArrayWithFormatToolArgument: ToolArgumentConvertible {
            let elementType: String
            let elementDescription: String
            let format: String
            let description: String
            var isOptional: Bool { false }
            
            func toPropertySchema() -> [String: any Sendable] {
                var schema: [String: any Sendable] = [
                    "type": "array",
                    "description": description
                ]
                
                // Create items schema with format
                let itemsSchema: [String: any Sendable] = [
                    "type": elementType,
                    "description": elementDescription,
                    "format": format
                ]
                
                schema["items"] = itemsSchema
                
                return schema
            }
        }
        
        return ArrayWithFormatToolArgument(
            elementType: elementType,
            elementDescription: elementDescription,
            format: format,
            description: description
        )
    }
    
    private func createNestedArrayToolArgument(nestedElementType: LLMToolArgumentType, description: String) -> any ToolArgumentConvertible {
        // Handle nested arrays (e.g., [[String]], [[Int]], etc.)
        struct NestedArrayToolArgument: ToolArgumentConvertible {
            let nestedElementType: LLMToolArgumentType
            let description: String
            var isOptional: Bool { false }
            
            func toPropertySchema() -> [String: any Sendable] {
                var schema: [String: any Sendable] = [
                    "type": "array",
                    "description": description
                ]
                
                // Create items schema for the nested array
                let itemsSchema: [String: any Sendable] = [
                    "type": "array",
                    "items": nestedElementType.asToolArgument.toPropertySchema()
                ]
                schema["items"] = itemsSchema
                
                return schema
            }
        }
        
        return NestedArrayToolArgument(nestedElementType: nestedElementType, description: description)
    }
    
    private func createArrayOfObjectsToolArgument(objectType: any ToolArgumentObject.Type, description: String) -> any ToolArgumentConvertible {
        // Handle arrays of custom object types
        struct ArrayOfObjectsToolArgument: ToolArgumentConvertible {
            let objectType: any ToolArgumentObject.Type
            let description: String
            var isOptional: Bool { false }
            
            func toPropertySchema() -> [String: any Sendable] {
                var schema: [String: any Sendable] = [
                    "type": "array",
                    "description": description
                ]
                
                // Get the object schema and use it as items schema
                let objectSchema = generateToolSchema(from: objectType.argumentsSchema)
                schema["items"] = objectSchema
                
                return schema
            }
        }
        
        return ArrayOfObjectsToolArgument(objectType: objectType, description: description)
    }
    
    private func createArrayOfOptionalsToolArgument(wrappedType: LLMToolArgumentType, description: String) -> any ToolArgumentConvertible {
        // Handle arrays of optional types (e.g., [String?], [Int?], etc.)
        struct ArrayOfOptionalsToolArgument: ToolArgumentConvertible {
            let wrappedType: LLMToolArgumentType
            let description: String
            var isOptional: Bool { false }
            
            func toPropertySchema() -> [String: any Sendable] {
                var schema: [String: any Sendable] = [
                    "type": "array",
                    "description": description
                ]
                
                // The items can be the wrapped type or null
                let wrappedSchema = wrappedType.asToolArgument.toPropertySchema()
                let itemsSchema: [String: any Sendable] = [
                    "oneOf": [
                        wrappedSchema,
                        ["type": "null"]
                    ]
                ]
                schema["items"] = itemsSchema
                
                return schema
            }
        }
        
        return ArrayOfOptionalsToolArgument(wrappedType: wrappedType, description: description)
    }
    
    private func createObjectToolArgument(type: any ToolArgumentObject.Type, description: String) -> any ToolArgumentConvertible {
        struct ObjectToolArgument: ToolArgumentConvertible {
            let objectType: any ToolArgumentObject.Type
            let description: String
            var isOptional: Bool { false }
            
            func toPropertySchema() -> [String: any Sendable] {
                var schema = generateToolSchema(from: objectType.argumentsSchema)
                schema["description"] = description
                return schema
            }
        }
        
        return ObjectToolArgument(objectType: type, description: description)
    }
    
    private func createArrayOfEnumsToolArgument(values: [any Sendable], elementDescription: String, description: String) -> any ToolArgumentConvertible {
        // Handle arrays of enum values
        struct ArrayOfEnumsToolArgument: ToolArgumentConvertible {
            let values: [any Sendable]
            let elementDescription: String
            let description: String
            var isOptional: Bool { false }
            
            func toPropertySchema() -> [String: any Sendable] {
                var schema: [String: any Sendable] = [
                    "type": "array",
                    "description": description
                ]
                
                // Create items schema with enum values
                var itemsSchema: [String: any Sendable] = [
                    "description": elementDescription,
                    "enum": values
                ]
                
                // Determine type based on enum values
                if values.first is Int {
                    itemsSchema["type"] = "integer"
                } else {
                    itemsSchema["type"] = "string"
                }
                
                schema["items"] = itemsSchema
                
                return schema
            }
        }
        
        return ArrayOfEnumsToolArgument(
            values: values,
            elementDescription: elementDescription,
            description: description
        )
    }
    
    private func createOptionalToolArgument(wrapped: LLMToolArgumentType) -> any ToolArgumentConvertible {
        struct OptionalToolArgument: ToolArgumentConvertible {
            let wrapped: any ToolArgumentConvertible
            var isOptional: Bool { true }
            
            func toPropertySchema() -> [String: any Sendable] {
                return wrapped.toPropertySchema()
            }
        }
        
        return OptionalToolArgument(wrapped: wrapped.asToolArgument)
    }
}

/// Generates a JSON Schema compatible tool schema from an arguments schema
/// - Parameter schema: A dictionary of property names to tool argument types
/// - Returns: A dictionary representing the JSON Schema
package func generateToolSchema(from schema: LLMToolArgumentsSchema) -> [String: any Sendable] {
    var properties: [String: [String: any Sendable]] = [:]
    var required: [String] = []
    
    for (propertyName, argumentType) in schema {
        let toolArg = argumentType.asToolArgument
        properties[propertyName] = toolArg.toPropertySchema()
        
        // Add to required if not optional
        if !toolArg.isOptional {
            required.append(propertyName)
        }
    }
    
    var result: [String: any Sendable] = [
        "type": "object",
        "properties": properties as [String: any Sendable]
    ]
    
    if !required.isEmpty {
        result["required"] = required
    }
    
    return result
}