import Foundation

#if canImport(FoundationModels)
import FoundationModels

enum AppleFoundationModelSchemaError: Error {
    case invalidRoot
    case unsupportedType(String)
}

@available(macOS 26.0, *)
enum AppleFoundationModelSchemaBuilder {
    static func makeSchema(from schema: LLMJSONSchema) throws -> GenerationSchema {
        guard case .string("object")? = schema.schema["type"] else {
            throw AppleFoundationModelSchemaError.invalidRoot
        }
        let root = try makeDynamicSchema(
            from: .object(schema.schema),
            name: sanitizedName(schema.name, fallback: "TypefluxResponse")
        )
        return try GenerationSchema(root: root, dependencies: [])
    }

    private static func makeDynamicSchema(
        from value: AnySendable,
        name: String
    ) throws -> DynamicGenerationSchema {
        guard case let .object(definition) = value,
              case let .string(type)? = definition["type"]
        else {
            throw AppleFoundationModelSchemaError.unsupportedType("missing")
        }

        switch type {
        case "object":
            return try makeObjectSchema(from: definition, name: name)
        case "array":
            return try makeArraySchema(from: definition, name: name)
        case "string":
            return makeStringSchema(from: definition, name: name)
        case "integer":
            return DynamicGenerationSchema(type: Int.self)
        case "number":
            return DynamicGenerationSchema(type: Double.self)
        case "boolean":
            return DynamicGenerationSchema(type: Bool.self)
        default:
            throw AppleFoundationModelSchemaError.unsupportedType(type)
        }
    }

    private static func makeObjectSchema(
        from definition: [String: AnySendable],
        name: String
    ) throws -> DynamicGenerationSchema {
        let required = stringSet(from: definition["required"])
        let properties: [String: AnySendable]
        if case let .object(values)? = definition["properties"] {
            properties = values
        } else {
            properties = [:]
        }
        let nativeProperties = try properties.keys.sorted().map { propertyName in
            let propertySchema = try makeDynamicSchema(
                from: properties[propertyName]!,
                name: sanitizedName("\(name)_\(propertyName)", fallback: "Property")
            )
            return DynamicGenerationSchema.Property(
                name: propertyName,
                schema: propertySchema,
                isOptional: !required.contains(propertyName)
            )
        }
        return DynamicGenerationSchema(
            name: name,
            description: stringValue(from: definition["description"]),
            properties: nativeProperties
        )
    }

    private static func makeArraySchema(
        from definition: [String: AnySendable],
        name: String
    ) throws -> DynamicGenerationSchema {
        guard let items = definition["items"] else {
            throw AppleFoundationModelSchemaError.unsupportedType("array without items")
        }
        return try DynamicGenerationSchema(
            arrayOf: makeDynamicSchema(from: items, name: "\(name)_Item"),
            minimumElements: intValue(from: definition["minItems"]),
            maximumElements: intValue(from: definition["maxItems"])
        )
    }

    private static func makeStringSchema(
        from definition: [String: AnySendable],
        name: String
    ) -> DynamicGenerationSchema {
        if case let .array(values)? = definition["enum"] {
            let choices = values.compactMap { value -> String? in
                guard case let .string(choice) = value else { return nil }
                return choice
            }
            if !choices.isEmpty {
                return DynamicGenerationSchema(name: name, anyOf: choices)
            }
        }
        return DynamicGenerationSchema(type: String.self)
    }

    private static func stringSet(from value: AnySendable?) -> Set<String> {
        guard case let .array(values)? = value else { return [] }
        return Set(values.compactMap { value -> String? in
            guard case let .string(string) = value else { return nil }
            return string
        })
    }

    private static func stringValue(from value: AnySendable?) -> String? {
        guard case let .string(string)? = value else { return nil }
        return string
    }

    private static func intValue(from value: AnySendable?) -> Int? {
        guard case let .int(number)? = value else { return nil }
        return number
    }

    private static func sanitizedName(_ value: String, fallback: String) -> String {
        let scalars = value.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : "_"
        }
        let result = String(scalars)
        return result.isEmpty ? fallback : result
    }
}
#endif
