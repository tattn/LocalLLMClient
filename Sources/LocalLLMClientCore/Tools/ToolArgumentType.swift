import Foundation

// MARK: - Tool Argument Types

/// Protocol for types that can be used as tool arguments
public protocol ToolArgumentType {
    /// The JSON Schema type string for this type
    static var toolArgumentType: String { get }
    
    /// For array types, returns the element type info
    static var arrayElementInfo: (type: String, elementType: (any ToolArgumentType.Type)?)? { get }
    
    /// For object types, returns the object schema
    static var objectSchema: [String: any Sendable]? { get }
    
    /// For enum types, returns the available enum values
    static var enumValues: [any Sendable]? { get }
}

// Default implementation for non-array and non-object types
extension ToolArgumentType {
    public static var arrayElementInfo: (type: String, elementType: (any ToolArgumentType.Type)?)? { nil }
    public static var objectSchema: [String: any Sendable]? { nil }
    public static var enumValues: [any Sendable]? { nil }
}

// MARK: - Standard Type Conformances

extension String: ToolArgumentType {
    public static var toolArgumentType: String { "string" }
}

extension Int: ToolArgumentType {
    public static var toolArgumentType: String { "integer" }
}

extension Int32: ToolArgumentType {
    public static var toolArgumentType: String { "integer" }
}

extension Int64: ToolArgumentType {
    public static var toolArgumentType: String { "integer" }
}

extension UInt: ToolArgumentType {
    public static var toolArgumentType: String { "integer" }
}

extension UInt32: ToolArgumentType {
    public static var toolArgumentType: String { "integer" }
}

extension UInt64: ToolArgumentType {
    public static var toolArgumentType: String { "integer" }
}

extension Double: ToolArgumentType {
    public static var toolArgumentType: String { "number" }
}

extension Float: ToolArgumentType {
    public static var toolArgumentType: String { "number" }
}

extension Bool: ToolArgumentType {
    public static var toolArgumentType: String { "boolean" }
}

extension Data: ToolArgumentType {
    public static var toolArgumentType: String { "string" }
}

extension Date: ToolArgumentType {
    public static var toolArgumentType: String { "string" }
}

extension URL: ToolArgumentType {
    public static var toolArgumentType: String { "string" }
}

// MARK: - RawRepresentable Support

extension RawRepresentable where Self: ToolArgumentType, Self.RawValue == String {
    public static var toolArgumentType: String { "string" }
}

extension RawRepresentable where Self: ToolArgumentType, Self.RawValue == Int {
    public static var toolArgumentType: String { "integer" }
}

extension RawRepresentable where Self: ToolArgumentType, Self.RawValue == Double {
    public static var toolArgumentType: String { "number" }
}

extension RawRepresentable where Self: ToolArgumentType, Self.RawValue == Float {
    public static var toolArgumentType: String { "number" }
}

// Auto-provide enum values for CaseIterable types
extension RawRepresentable where Self: ToolArgumentType & CaseIterable, RawValue: Sendable {
    public static var enumValues: [any Sendable]? {
        Self.allCases.map { $0.rawValue }
    }
}

// MARK: - Optional Support

extension Optional: ToolArgumentType where Wrapped: ToolArgumentType {
    public static var toolArgumentType: String { Wrapped.toolArgumentType }
    public static var arrayElementInfo: (type: String, elementType: (any ToolArgumentType.Type)?)? {
        Wrapped.arrayElementInfo
    }
    public static var enumValues: [any Sendable]? { Wrapped.enumValues }
    public static var objectSchema: [String: any Sendable]? { Wrapped.objectSchema }
}

// MARK: - Array Support

extension Array: ToolArgumentType where Element: ToolArgumentType {
    public static var toolArgumentType: String { "array" }
    public static var arrayElementInfo: (type: String, elementType: (any ToolArgumentType.Type)?)? {
        (type: Element.toolArgumentType, elementType: Element.self)
    }
}