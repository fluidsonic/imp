import Foundation
import JetPack


public struct StringsParser {

	private static let pluralKeyPattern = try! NSRegularExpression(pattern: "^([^$]+)\\$(.+)$", options: [])


	public func makeHierarchical(items: [Key : Strings.Item]) throws -> Strings {
		class TemporaryNamespace {

			var items: [KeyComponent : Strings.Item] = [:]
			var namespaces: [KeyComponent : TemporaryNamespace] = [:]


			func toStringsNamespace() -> Strings.Namespace {
				return Strings.Namespace(
					items:      items,
					namespaces: namespaces.mapAsDictionary { ($0, $1.toStringsNamespace()) }
				)
			}
		}


		let rootNode = TemporaryNamespace()

		for (key, item) in items {
			var parentNode = rootNode

			guard let keyPath = KeyPath(key) else {
				throw Error(message: "Invalid key path '\(key)'.")
			}

			for index in keyPath.startIndex ..< keyPath.endIndex - 1 {
				let keyComponent = keyPath[index]
				if let childNode = parentNode.namespaces[keyComponent] {
					parentNode = childNode
				}
				else {
					let childNode = TemporaryNamespace()
					parentNode.namespaces[keyComponent] = childNode
					parentNode = childNode
				}
			}

			let lastKeyComponent = keyPath[keyPath.endIndex - 1]
			parentNode.items[lastKeyComponent] = item
		}

		return Strings(rootNamespace: rootNode.toStringsNamespace())
	}


	public func makeSkeleton(of strings: Strings) -> StringsSkeleton {
		func skeletonForItem(item: Strings.Item) -> StringsSkeleton.Item {
			switch item {
			case let .pluralized(values, keyTemplateParameterName):
				var parameters = Set<ParameterName>()
				var orderedParameters = [ParameterName]()
				var isTemplate = false

				for value in values.values {
					switch value {
					case .constant:
						break

					case let .template(components):
						isTemplate = true

						for case let .parameter(parameter) in components where !parameters.contains(parameter) {
							parameters.insert(parameter)
							orderedParameters.append(parameter)
						}
					}
				}

				if isTemplate {
					return .pluralized(value: .template(parameterNames: orderedParameters), pluralCategories: Set(values.keys), keyTemplateParameterName: keyTemplateParameterName)
				}
				else {
					return .pluralized(value: .constant, pluralCategories: Set(values.keys), keyTemplateParameterName: keyTemplateParameterName)
				}

			case .simple(.constant):
				return .simple(value: .constant)

			case let .simple(.template(components)):
				var parameters = Set<ParameterName>()
				var orderedParameters = [ParameterName]()

				for case let .parameter(parameter) in components where !parameters.contains(parameter) {
					parameters.insert(parameter)
					orderedParameters.append(parameter)
				}

				return .simple(value: .template(parameterNames: orderedParameters))
			}
		}

		func skeletonForNamespace(namespace: Strings.Namespace) -> StringsSkeleton.Namespace {
			return StringsSkeleton.Namespace(
				items:      namespace.items.mapAsDictionary { ($0, skeletonForItem($1)) },
				namespaces: namespace.namespaces.mapAsDictionary { ($0, skeletonForNamespace($1)) }
			)
		}


		return StringsSkeleton(rootNamespace: skeletonForNamespace(strings.rootNamespace))
	}
	

	public func parse(data data: NSData) throws -> [Key : Strings.Item] {
		guard data.length > 0 else {
			return [:]
		}

		let content: AnyObject
		do {
			content = try NSPropertyListSerialization.propertyListWithData(data, options: .Immutable, format: nil)
		}
		catch let error as NSError {
			let parsingError = error.userInfo["kCFPropertyListOldStyleParsingError"] as? NSError ?? error
			let message = parsingError.userInfo["NSDebugDescription"] as? String ?? parsingError.localizedDescription

			throw Error(message: message)
		}

		guard let dictionary = content as? [NSObject : AnyObject] else {
			throw Error(message: "Not in .strings format")
		}

		var simpleValuesByKey: [Key : Strings.Value] = [:]
		var keyTemplateParameterNameByKey: [Key : ParameterName] = [:]
		var pluralizedValuesByKey: [Key : StrongReference<[NSLocale.PluralCategory : Strings.Value]>] = [:]

		for (rawKey, rawValue) in dictionary {
			guard let stringKey = rawKey as? String else {
				throw Error(message: "Strings key must be a string: \(rawKey)")
			}

			let (value, keyTemplateParameterName) = try parseValue(rawValue, key: stringKey)

			if let match = stringKey.firstMatchForRegularExpression(StringsParser.pluralKeyPattern), key = match[1].map({ Key($0) }), rawPluralCategory = match[2] {
				guard let pluralCategory = parsePluralCategory(rawPluralCategory) else {
					throw Error(message: "String '\(stringKey)' uses unknown plural category '\(rawPluralCategory)'. Supported plural categories: few, many, one, other, two & zero.")
				}

				if let pluralizedValues = pluralizedValuesByKey[key] {
					pluralizedValues.target[pluralCategory] = value
				}
				else {
					pluralizedValuesByKey[key] = StrongReference([pluralCategory : value])
				}

				if let keyTemplateParameterName = keyTemplateParameterName {
					if let existingKeyTemplateParameterName = keyTemplateParameterNameByKey[key] where existingKeyTemplateParameterName != keyTemplateParameterName {
						throw Error(message: "String '\(key)' cannot have multiple key template parameters ('\(existingKeyTemplateParameterName)' and '\(keyTemplateParameterName)' are both using {#…} syntax).")
					}

					keyTemplateParameterNameByKey[key] = keyTemplateParameterName
				}
			}
			else {
				simpleValuesByKey[Key(stringKey)] = value
			}
		}

		var itemsByKey: [Key : Strings.Item] = [:]
		for (key, value) in simpleValuesByKey {
			itemsByKey[key] = .simple(value)
		}
		for (key, values) in pluralizedValuesByKey {
			if itemsByKey[key] != nil {
				throw Error(message: "String '\(key)' cannot have pluralized and non-pluralized values.")
			}

			itemsByKey[key] = .pluralized(values.target, keyTemplateParameterName: keyTemplateParameterNameByKey[key])
		}

		return itemsByKey
	}


	private func parsePluralCategory(id: String) -> NSLocale.PluralCategory? {
		switch id {
		case "few":   return .few
		case "many":  return .many
		case "one":   return .one
		case "other": return .other
		case "two":   return .two
		case "zero":  return .zero
		default:      return nil
		}
	}


	private func parseValue(rawValue: AnyObject, key: String) throws -> (Strings.Value, ParameterName?) {
		guard let valueToParse = rawValue as? String else {
			throw Error(message: "Strings value must be a string: \(rawValue)")
		}

		var components: [Strings.Value.TemplateComponent] = []
		var currentConstant = ""
		var currentParameterIsKeyForPluralizedString = false
		var currentParameterName = ""
		var hasParameters = false
		var isParsingParameter = false
		var isAwaitingClosingCurlyBracket = false
		var position = 0
		var keyParameterNameForPluralizedStrings: ParameterName?

		func error(message message: String) -> Error {
			return Error(message: "\(message) - at position \(position) of '\(valueToParse)'")
		}

		for character in valueToParse.characters {
			defer { position += 1 }

			if isAwaitingClosingCurlyBracket && character != "}" {
				throw error(message: "Unexpected '}'. Either you forgot a '{' before it to start a parameter or you should escape the '}' using '}}'.")
			}

			switch character {
			case "{":
				if isParsingParameter {
					if !currentParameterName.isEmpty {
						throw error(message: "Unexpected '{'. Either you forgot a '}' before it to end a parameter or you should escape the first '{' using '{{'.")
					}

					isParsingParameter = false
					currentConstant += "{"
				}
				else {
					isParsingParameter = true
				}

			case "}":
				if isParsingParameter {
					if currentParameterName.isEmpty {
						throw error(message: "Unexpected '}'. Either you forgot the parameter name or you should escape the '{' and '}' using '{{' and '}}' respectively.")
					}

					if !currentConstant.isEmpty {
						components.append(.constant(currentConstant))
						currentConstant = ""
					}

					let parameterName = ParameterName(currentParameterName)
					if currentParameterIsKeyForPluralizedString {
						if let keyParameterNameForPluralizedString = keyParameterNameForPluralizedStrings where keyParameterNameForPluralizedString != parameterName {
							throw error(message: "Template cannot have multiple key parameters ('\(keyParameterNameForPluralizedString)' and '\(parameterName)' are both using {#…} syntax).")
						}

						keyParameterNameForPluralizedStrings = parameterName
					}

					components.append(.parameter(name: parameterName))
					currentParameterIsKeyForPluralizedString = false
					currentParameterName = ""
					hasParameters = true
					isParsingParameter = false
				}
				else if isAwaitingClosingCurlyBracket {
					isAwaitingClosingCurlyBracket = false
				}
				else {
					currentConstant += "}"
					isAwaitingClosingCurlyBracket = true
				}

			case "#" where isParsingParameter && currentParameterName.isEmpty && !currentParameterIsKeyForPluralizedString:
				currentParameterIsKeyForPluralizedString = true

			default:
				if isParsingParameter {
					currentParameterName.append(character)
				}
				else {
					currentConstant.append(character)
				}
			}
		}

		if isParsingParameter {
			throw error(message: "Unexpected end of value. Either you forgot a '}' to end a parameter or you should escape the last '{' using '{{'.")
		}
		if isAwaitingClosingCurlyBracket {
			throw error(message: "Unexpected end of value. Either you forgot a '{' before it to start a parameter or you should escape the '}' using '}}'.")
		}

		if !hasParameters {
			return (.constant(currentConstant), nil)
		}

		if !currentConstant.isEmpty {
			components.append(.constant(currentConstant))
		}

		return (.template(components: components), keyParameterNameForPluralizedStrings)
	}



	public struct Error: CustomStringConvertible, ErrorType {

		public var message: String


		public var description: String {
			return "Strings: \(message)"
		}
	}
}
