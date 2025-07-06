import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

enum MacroError: Error, CustomStringConvertible {
    case notAStruct
    
    var description: String {
        switch self {
        case .notAStruct:
            return "@ToolArguments can only be applied to structs"
        }
    }
}

// Helper function to check if a type is a built-in Swift type
private func isBuiltInType(_ typeName: String) -> Bool {
    let builtInTypes = Set([
        "String", "Int", "Int8", "Int16", "Int32", "Int64",
        "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
        "Double", "Float", "Float32", "Float64", "Float80",
        "Bool", "Data", "Date", "URL", "UUID",
        "Array", "Dictionary", "Set", "Optional",
        "Decimal", "Character"
    ])
    return builtInTypes.contains(typeName)
}

public struct ToolArgumentsMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.notAStruct
        }
        
        // Generate the argumentsSchema static property
        let argumentsSchema = try generateArgumentsSchema(from: structDecl)
        
        return [DeclSyntax(argumentsSchema)]
    }
    
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.as(StructDeclSyntax.self) != nil else {
            throw MacroError.notAStruct
        }
        
        // Create an extension that conforms to Decodable, ToolSchemaGeneratable and ToolArgumentObject
        let extensionDecl = try ExtensionDeclSyntax(
            """
            extension \(type): Decodable, ToolSchemaGeneratable, ToolArgumentObject {}
            """
        )
        
        return [extensionDecl]
    }
    
    private static func generateArgumentsSchema(from structDecl: StructDeclSyntax) throws -> VariableDeclSyntax {
        var schemaEntries: [String] = []
        let parentTypeName = structDecl.name.text
        
        // Iterate through all properties in the Arguments struct
        for member in structDecl.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self),
                  let binding = variable.bindings.first,
                  let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                  let typeAnnotation = binding.typeAnnotation?.type else {
                continue
            }
            
            let propertyName = identifier.identifier.text
            
            // Check if property has @ToolArgument attribute
            let toolArgumentAttr = variable.attributes.first { attribute in
                attribute.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "ToolArgument"
            }?.as(AttributeSyntax.self)
            
            if let toolArgumentAttr = toolArgumentAttr {
                // Extract parameters from @ToolArgument
                let (description, enumValues, format) = extractToolArgumentParameters(from: toolArgumentAttr)
                
                // Check if the type conforms to CaseIterable to auto-detect enum values
                let autoEnumValues = checkCaseIterableType(typeAnnotation, parentTypeName: parentTypeName)
                let finalEnumValues = enumValues ?? autoEnumValues
                
                // Generate the schema entry
                let schemaEntry = generateSchemaEntry(
                    propertyName: propertyName,
                    type: typeAnnotation,
                    parentTypeName: parentTypeName,
                    description: description,
                    enumValues: finalEnumValues,
                    format: format
                )
                
                schemaEntries.append(schemaEntry)
            }
        }
        
        // Create the argumentsSchema static property
        let schemaDict = schemaEntries.isEmpty ? "[:]" : "[\n                \(schemaEntries.joined(separator: ",\n                "))\n            ]"
        
        return try VariableDeclSyntax(
            """
            public static var argumentsSchema: LLMToolArgumentsSchema {
                \(raw: schemaDict)
            }
            """
        )
    }
    
    private static func extractToolArgumentParameters(from attribute: AttributeSyntax) -> (description: String, enumValues: String?, format: String?) {
        var description = "\"\""
        var enumValues: String? = nil
        var format: String? = nil
        
        if let arguments = attribute.arguments?.as(LabeledExprListSyntax.self) {
            for argument in arguments {
                switch argument.label?.text {
                case "description", .none:
                    if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                        description = "\"\(stringLiteral.segments.description)\""
                    }
                case "enum":
                    if let arrayExpr = argument.expression.as(ArrayExprSyntax.self) {
                        let values = arrayExpr.elements.compactMap { element in
                            if let stringLiteral = element.expression.as(StringLiteralExprSyntax.self) {
                                return "\"\(stringLiteral.segments.description)\""
                            } else if let intLiteral = element.expression.as(IntegerLiteralExprSyntax.self) {
                                return intLiteral.literal.text
                            }
                            return nil
                        }
                        if !values.isEmpty {
                            enumValues = "[\(values.joined(separator: ", "))]"
                        }
                    }
                case "format":
                    if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                        format = "\"\(stringLiteral.segments.description)\""
                    }
                default:
                    break
                }
            }
        }
        
        return (description, enumValues, format)
    }
    
    private static func generateSchemaEntry(
        propertyName: String,
        type: TypeSyntax,
        parentTypeName: String,
        description: String,
        enumValues: String?,
        format: String?
    ) -> String {
        let typeString = type.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let isOptional = typeString.contains("?")
        let cleanType = typeString.replacingOccurrences(of: "?", with: "")
        
        // Determine the schema type based on the Swift type
        var schemaType: String
        
        if let enumValues = enumValues {
            // If enum values are provided, use .enum
            schemaType = ".enum(values: \(enumValues), description: \(description))"
        } else if cleanType.hasPrefix("[") && cleanType.contains(":") {
            // Dictionary type - we can't represent this directly in our schema system
            // So we'll use a string type with a description indicating it's a dictionary/map
            schemaType = ".string(description: \(description))"
        } else if cleanType.hasPrefix("[") {
            // Array type
            let elementType = extractArrayElementType(from: cleanType)
            let elementSchemaType = mapTypeToSchemaType(elementType, parentTypeName: parentTypeName, description: "\"Element\"", format: nil)
            schemaType = ".array(of: \(elementSchemaType), description: \(description))"
        } else if cleanType == "Data" {
            // Data type with format
            let formatStr = format ?? "\"byte\""
            schemaType = ".string(description: \(description), format: \(formatStr))"
        } else if !isBuiltInType(cleanType) && !cleanType.contains(".") {
            // Check if this might be an enum type based on the auto-detected enum values
            let autoEnumValues = checkCaseIterableType(type, parentTypeName: parentTypeName)
            if let autoEnumValues = autoEnumValues {
                // This is likely an enum type
                schemaType = ".enum(values: \(autoEnumValues), description: \(description))"
            } else {
                // Custom object type - use the type name directly without qualification
                schemaType = ".object(\(cleanType).self, description: \(description))"
            }
        } else {
            // Built-in type
            schemaType = mapTypeToSchemaType(cleanType, parentTypeName: parentTypeName, description: description, format: format)
        }
        
        // Handle optionals
        if isOptional {
            schemaType = ".optional(\(schemaType))"
        }
        
        return "\"\(propertyName)\": \(schemaType)"
    }
    
    private static func mapTypeToSchemaType(_ typeString: String, parentTypeName: String, description: String, format: String?) -> String {
        let cleanType = typeString.replacingOccurrences(of: "?", with: "")
        
        switch cleanType {
        case "String":
            if let format = format {
                return ".string(description: \(description), format: \(format))"
            } else {
                return ".string(description: \(description))"
            }
        case "Int", "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16", "UInt32", "UInt64":
            return ".integer(description: \(description))"
        case "Double", "Float", "Float32", "Float64", "Float80":
            return ".number(description: \(description))"
        case "Bool":
            return ".boolean(description: \(description))"
        case "Data":
            return ".string(description: \(description), format: \"byte\")"
        default:
            if !isBuiltInType(cleanType) && !cleanType.contains(".") {
                // Check if this is an enum type by checking for allCases
                let typeNode = TypeSyntax(IdentifierTypeSyntax(name: .identifier(cleanType)))
                let autoEnumValues = checkCaseIterableType(typeNode, parentTypeName: parentTypeName)
                if let autoEnumValues = autoEnumValues {
                    return ".enum(values: \(autoEnumValues), description: \(description))"
                } else {
                    return ".object(\(cleanType).self, description: \(description))"
                }
            } else {
                return ".string(description: \(description))"
            }
        }
    }
    
    private static func extractArrayElementType(from arrayType: String) -> String {
        // Extract element type from array syntax like [String] or [Int]
        // Handle dictionary types like [String: Int]
        if arrayType.hasPrefix("[") && arrayType.hasSuffix("]") {
            let startIndex = arrayType.index(after: arrayType.startIndex)
            let endIndex = arrayType.index(before: arrayType.endIndex)
            let inner = String(arrayType[startIndex..<endIndex])
            
            // For dictionary types, we can't easily represent them in our schema
            // So we'll treat them as objects
            if inner.contains(":") {
                return "Object"
            }
            
            return inner
        }
        return "String"
    }
    
    private static func qualifyTypeName(_ type: TypeSyntax, parentTypeName: String) -> String {
        var typeString = type.description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle optional types first
        if let optionalType = type.as(OptionalTypeSyntax.self),
           let wrappedType = optionalType.wrappedType.as(IdentifierTypeSyntax.self) {
            let wrappedTypeName = wrappedType.name.text
            if !isBuiltInType(wrappedTypeName) && !wrappedTypeName.contains(".") {
                typeString = "\(parentTypeName).\(wrappedTypeName)?"
            }
        } else if let identifierType = type.as(IdentifierTypeSyntax.self) {
            let typeName = identifierType.name.text
            // Check if this is likely a nested type
            if !isBuiltInType(typeName) && !typeName.contains(".") {
                typeString = "\(parentTypeName).\(typeName)"
            }
        }
        
        return typeString
    }
    
    private static func checkCaseIterableType(_ type: TypeSyntax, parentTypeName: String) -> String? {
        // Check if the type is an enum that conforms to CaseIterable
        // Since we can't check conformance at compile time in the macro,
        // we'll use a heuristic: if it's a nested type and not a built-in type
        let typeString = type.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanType = typeString.replacingOccurrences(of: "?", with: "")
        
        // Skip built-in types, arrays, and known struct types
        if isBuiltInType(cleanType) || cleanType.hasPrefix("[") || cleanType.contains(":") {
            return nil
        }
        
        // List of known struct/class type names that should not be treated as enums
        let knownNonEnumTypes = Set(["UserInfo", "Config", "Settings", "Metadata", "UserProfile", "Address", "Preferences", "NotificationSettings"])
        
        // For nested enum types like Status, Priority, etc.
        // Generate the CaseIterable values syntax
        if let identifierType = type.as(IdentifierTypeSyntax.self) {
            let typeName = identifierType.name.text
            if !typeName.contains(".") && !knownNonEnumTypes.contains(typeName) {
                // This might be a nested enum - but we can't be sure at compile time
                // So we only generate this for types that look like enums
                // (short names, not matching known struct patterns)
                if typeName.count < 20 && !typeName.hasSuffix("Info") && !typeName.hasSuffix("Config") {
                    // Check if the type is already qualified with parent type
                    if typeName.contains(".") {
                        return "\(typeName).allCases.map { $0.rawValue }"
                    } else {
                        // Try as a standalone type first, then as nested
                        return "\(typeName).allCases.map { $0.rawValue }"
                    }
                }
            }
        } else if let optionalType = type.as(OptionalTypeSyntax.self),
                  let wrappedType = optionalType.wrappedType.as(IdentifierTypeSyntax.self) {
            let typeName = wrappedType.name.text
            if !typeName.contains(".") && !knownNonEnumTypes.contains(typeName) {
                // Same logic for optional wrapped types
                if typeName.count < 20 && !typeName.hasSuffix("Info") && !typeName.hasSuffix("Config") {
                    return "\(parentTypeName).\(typeName).allCases.map { $0.rawValue }"
                }
            }
        }
        
        return nil
    }
}