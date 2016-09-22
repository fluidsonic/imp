import Foundation
import JetPack


public struct SwiftStringsGenerator: StringsGenerator {

	private let emitsJetPackImport: Bool
	private let tableName: String?
	private let typeName: String
	private let visibility: String


	public init(typeName: String = "Strings", visibility: Visibility = .internalVisibility, tableName: String? = nil, emitsJetPackImport: Bool = true) {
		self.emitsJetPackImport = emitsJetPackImport
		self.tableName = tableName
		self.typeName = typeName

		switch visibility {
		case .internalVisibility: self.visibility = "internal"
		case .publicVisibility:   self.visibility = "public"
		}
	}


	public func generate(for skeleton: StringsSkeleton) -> String {
		let skeletonUsesPluralizedStrings = self.skeletonUsesPluralizedStrings(skeleton)
		let writer = Writer()

		writer.line("import Foundation")
		if emitsJetPackImport && skeletonUsesPluralizedStrings {
			writer.line("import JetPack")
		}
		writer.line()

		generate(for: skeleton.rootNamespace, writer: writer, parentKeyPath: [], lastKeyComponent: nil)

		let tableName = self.tableName.map({ "\"\($0)\"" }) ?? "nil"

		writer.line()
		writer.line()
		writer.line()

		writer.line("private let __bundle: NSBundle = {")
		writer.indent() {
			writer.line("class Dummy {}")
			writer.line()
			writer.line("return NSBundle(forClass: Dummy.self)")
		}
		writer.line("}()")

		if skeletonUsesPluralizedStrings {

			writer.line()
			writer.line()

			writer.line("private let __defaultFormatter: NSNumberFormatter = {")
			writer.indent() {
				writer.line("let formatter = NSNumberFormatter()")
				writer.line("formatter.locale = NSLocale.autoupdatingCurrentLocale()")
				writer.line("formatter.numberStyle = .DecimalStyle")
				writer.line()
				writer.line("return formatter")
			}
			writer.line("}()")

			writer.line()
			writer.line()

			writer.line("private func __keySuffixForPluralCategory(category: NSLocale.PluralCategory) -> String {")
			writer.indent() {
				writer.line("switch category {")
				writer.line("case .few:   return \"$few\"")
				writer.line("case .many:  return \"$many\"")
				writer.line("case .one:   return \"$one\"")
				writer.line("case .other: return \"$other\"")
				writer.line("case .two:   return \"$two\"")
				writer.line("case .zero:  return \"$zero\"")
				writer.line("}")
			}
			writer.line("}")
		}

		writer.line()
		writer.line()

		writer.line("private func __string(key: String, parameters: [String : String]? = nil) -> String {")
		writer.indent() {
			writer.line("guard let value = __tryString(key) else {")
			writer.indent() {
				writer.line("return key")
			}
			writer.line("}")
			writer.line()
			writer.line("if let parameters = parameters {")
			writer.indent() {
				writer.line("return __substituteTemplateParameters(value, parameters: parameters)")
			}
			writer.line("}")
			writer.line()
			writer.line("return value")
		}
		writer.line("}")

		if skeletonUsesPluralizedStrings {
			writer.line()
			writer.line()

			writer.line("private func __string(key: String, number: NSNumber, formatter: NSNumberFormatter, parameters: [String : String]?) -> String {")
			writer.indent() {
				writer.line("return __string(key, pluralCategory: NSLocale.currentLocale().pluralCategoryForNumber(number, formatter: formatter), parameters: parameters)")
			}
			writer.line("}")

			writer.line()
			writer.line()

			writer.line("private func __string(key: String, pluralCategory: NSLocale.PluralCategory, parameters: [String : String]?) -> String {")
			writer.indent() {
				writer.line("let keySuffix = __keySuffixForPluralCategory(pluralCategory)")
				writer.line("guard let value = __tryString(\"\\(key)\\(keySuffix)\") ?? __tryString(\"\\(key)$other\") else {")
				writer.indent() {
					writer.line("return \"\\(key)$other\"")
				}
				writer.line("}")
				writer.line()
				writer.line("if let parameters = parameters {")
				writer.indent() {
					writer.line("return __substituteTemplateParameters(value, parameters: parameters)")
				}
				writer.line("}")
				writer.line()
				writer.line("return value")
			}
			writer.line("}")
		}

		writer.line()
		writer.line()

		writer.line("private func __substituteTemplateParameters(template: String, parameters: [String : String]) -> String {")
		writer.indent() {
			writer.line("var result = \"\"")
			writer.line()
			writer.line("var currentParameter = \"\"")
			writer.line("var isParsingParameter = false")
			writer.line("var isAwaitingClosingCurlyBracket = false")
			writer.line()
			writer.line("for character in template.characters {")
			writer.indent() {
				writer.line("if isAwaitingClosingCurlyBracket && character != \"}\" {")
				writer.indent() {
					writer.line("return template")
				}
				writer.line("}")
				writer.line()
				writer.line("switch character {")
				writer.line("case \"{\":")
				writer.indent() {
					writer.line("if isParsingParameter {")
					writer.indent() {
						writer.line("if !currentParameter.isEmpty {")
						writer.indent() {
							writer.line("return template")
						}
						writer.line("}")
						writer.line()
						writer.line("isParsingParameter = false")
						writer.line("result += \"{\"")
					}
					writer.line("}")
					writer.line("else {")
					writer.indent() {
						writer.line("isParsingParameter = true")
					}
					writer.line("}")
				}
				writer.line()
				writer.line("case \"}\":")
				writer.indent() {
					writer.line("if isParsingParameter {")
					writer.indent() {
						writer.line("if currentParameter.isEmpty {")
						writer.indent() {
							writer.line("return template")
						}
						writer.line("}")
						writer.line()
						writer.line("result += parameters[currentParameter] ?? \"{\\(currentParameter)}\"")
						writer.line("currentParameter = \"\"")
						writer.line("isParsingParameter = false")
					}
					writer.line("}")
					writer.line("else if isAwaitingClosingCurlyBracket {")
					writer.indent() {
						writer.line("isAwaitingClosingCurlyBracket = false")
					}
					writer.line("}")
					writer.line("else {")
					writer.indent() {
						writer.line("result += \"}\"")
						writer.line("isAwaitingClosingCurlyBracket = true")
					}
					writer.line("}")
				}
				writer.line()
				writer.line("default:")
				writer.indent() {
					writer.line("if isParsingParameter {")
					writer.indent() {
						writer.line("currentParameter.append(character)")
					}
					writer.line("}")
					writer.line("else {")
					writer.indent() {
						writer.line("result.append(character)")
					}
					writer.line("}")
				}
				writer.line("}")
			}
			writer.line("}")
			writer.line()
			writer.line("guard !isParsingParameter && !isAwaitingClosingCurlyBracket else {")
			writer.indent() {
				writer.line("return template")
			}
			writer.line("}")
			writer.line()
			writer.line("return result")
		}
		writer.line("}")

		writer.line()
		writer.line()

		writer.line("private func __tryString(key: String) -> String? {")
		writer.indent() {
			writer.line("let value = __bundle.localizedStringForKey(key, value: \"\\u{0}\", table: \(tableName))")
			writer.line("guard value != \"\\u{0}\" else {")
			writer.indent() {
				writer.line("return nil")
			}
			writer.line("}")
			writer.line("")
			writer.line("return value")
		}
		writer.line("}")

		if skeletonUsesPluralizedStrings {
			writer.line()
			writer.line()
			writer.line()

			writer.line("private struct __PluralizedString: PluralizedString {")
			writer.indent() {
				writer.line()
				writer.line("private var key: String")
				writer.line("private var parameters: [String : String]?")

				writer.line()
				writer.line()

				writer.line("private init(_ key: String, parameters: [String : String]? = nil) {")
				writer.indent() {
					writer.line("self.key = key")
					writer.line("self.parameters = parameters")
				}
				writer.line("}")

				writer.line()
				writer.line()

				writer.line("private func forPluralCategory(pluralCategory: NSLocale.PluralCategory) -> String {")
				writer.indent() {
					writer.line("return __string(key, pluralCategory: pluralCategory, parameters: parameters)")
				}
				writer.line("}")
			}
			writer.line("}")
		}

		return writer.buffer
	}


	private func generate(for namespace: StringsSkeleton.Namespace, writer: Writer, parentKeyPath: KeyPath, lastKeyComponent: KeyComponent?) {
		let enumName: String
		let keyPath: KeyPath

		if let lastKeyComponent = lastKeyComponent {
			enumName = lastKeyComponent.value.firstCharacterCapitalized
			keyPath = parentKeyPath + lastKeyComponent
		}
		else {
			enumName = typeName
			keyPath = parentKeyPath
		}

		writer.line()
		writer.line() {
			writer.add(visibility)
			writer.add(" enum ")
			writer.addIdentifier(enumName)
			writer.add(" {")
		}
		writer.indent() {
			for (keyComponent, namespace) in namespace.namespaces.sort({ $0.0 < $1.0 }) {
				generate(for: namespace, writer: writer, parentKeyPath: keyPath, lastKeyComponent: keyComponent)
			}

			if !namespace.items.isEmpty {
				writer.line()
			}

			for (keyComponent, item) in namespace.items.sort({ $0.0 < $1.0 }) {
				generate(for: item, writer: writer, parentKeyPath: keyPath, lastKeyComponent: keyComponent)
			}
		}
		writer.line("}")

		if lastKeyComponent != nil {
			writer.line()
		}
	}


	private func generate(for item: StringsSkeleton.Item, writer: Writer, parentKeyPath: KeyPath, lastKeyComponent: KeyComponent) {
		func next(for value: StringsSkeleton.Value, pluralCategories: Set<NSLocale.PluralCategory>? = nil, keyTemplateParameterName: ParameterName? = nil) {
			generate(for: value, pluralCategories: pluralCategories, keyTemplateParameterName: keyTemplateParameterName, writer: writer, parentKeyPath: parentKeyPath, lastKeyComponent: lastKeyComponent)
		}

		switch item {
		case let .pluralized(value, pluralCategories, keyTemplateParameterName):
			next(for: value, pluralCategories: pluralCategories, keyTemplateParameterName: keyTemplateParameterName)

		case let .simple(value):
			next(for: value)
		}
	}


	private func generate(for value: StringsSkeleton.Value, pluralCategories: Set<NSLocale.PluralCategory>?, keyTemplateParameterName: ParameterName?, writer: Writer, parentKeyPath: KeyPath, lastKeyComponent: KeyComponent) {
		func writeKeyPath() {
			if !parentKeyPath.isEmpty {
				for component in parentKeyPath {
					writer.add(component.value)
					writer.add(".")
				}
			}

			writer.add(lastKeyComponent.value)
		}

		switch value {
		case .constant:
			let returnType = pluralCategories != nil ? "PluralizedString" : "String"

			writer.line() {
				writer.add(visibility)
				writer.add(" static var  ")
				writer.addIdentifier(lastKeyComponent.value)
				writer.add(": ")
				writer.add(returnType)
				writer.add(" { return ")

				if pluralCategories == nil {
					writer.add("__string")
				}
				else {
					writer.add("__PluralizedString")
				}

				writer.add("(\"")
				writeKeyPath()
				writer.add("\")")

				writer.add(" }")
			}

		case let .template(parameterNames):
			func writeParameterDictionary() {
				writer.add("[")
				for (index, parameterName) in parameterNames.enumerate() {
					let isKeyParameter = parameterName == keyTemplateParameterName

					if index > 0 {
						writer.add(", ")
					}

					writer.add("\"")
					if isKeyParameter {
						writer.add("#")
					}
					writer.add(parameterName.value)
					writer.add("\": ")
					if isKeyParameter {
						writer.add("formatter.stringFromNumber(")
						writer.addIdentifier(parameterName.value)
						writer.add(") ?? \"\"")
					}
					else {
						writer.addIdentifier(parameterName.value)
					}
				}
				writer.add("]")
			}

			writer.line() {
				writer.add(visibility)
				writer.add(" static func ")
				writer.addIdentifier(lastKeyComponent.value)
				writer.add("(")

				for (index, parameterName) in parameterNames.enumerate() {
					if index == 0 {
						writer.addIdentifier(parameterName.value)
					}
					else {
						writer.add(",")
					}
					writer.add(" ")

					writer.addIdentifier(parameterName.value)
					writer.add(": ")

					if parameterName == keyTemplateParameterName {
						writer.add("NSNumber")
					}
					else {
						writer.add("String")
					}
				}

				if keyTemplateParameterName != nil {
					writer.add(", formatter: NSNumberFormatter = __defaultFormatter")
				}

				writer.add(") -> ")
				if pluralCategories == nil || keyTemplateParameterName != nil {
					writer.add("String")
				}
				else {
					writer.add("PluralizedString")
				}
				writer.add(" { return ")
				if pluralCategories == nil || keyTemplateParameterName != nil {
					writer.add("__string")
				}
				else {
					writer.add("__PluralizedString")
				}
				writer.add("(\"")
				writeKeyPath()
				writer.add("\"")
				if let keyTemplateParameterName = keyTemplateParameterName {
					writer.add(", number: ")
					writer.addIdentifier(keyTemplateParameterName.value)
					writer.add(", formatter: formatter")
				}
				writer.add(", parameters: ")
				writeParameterDictionary()

				writer.add(") }")
			}
		}
	}


	private func skeletonUsesPluralizedStrings(skeleton: StringsSkeleton) -> Bool {
		func namespaceUsesPluralizedStrings(namespace: StringsSkeleton.Namespace) -> Bool {
			for case .pluralized in namespace.items.values {
				return true
			}
			for namespace in namespace.namespaces.values where namespaceUsesPluralizedStrings(namespace) {
				return true
			}

			return false
		}

		return namespaceUsesPluralizedStrings(skeleton.rootNamespace)
	}



	public enum Visibility {

		case internalVisibility
		case publicVisibility
	}
}



private extension String {

	private var firstCharacterCapitalized: String {
		guard !isEmpty else {
			return self
		}

		let breakpoint = startIndex.advancedBy(1)
		return self[startIndex ..< breakpoint].uppercaseString + self[breakpoint ..< endIndex]
	}
}



private final class Writer {

	private static let swiftKeywords: Set<String> = [
		"associatedtype", "class", "deinit", "enum", "extension", "func", "import", "init", "inout", "internal", "let", "operator", "private", "protocol", "public", "static", "struct", "subscript", "typealias", "var",
		"break", "case", "continue", "default", "defer", "do", "else", "fallthrough", "for", "guard", "if", "in", "repeat", "return", "switch", "where", "while",
		"as", "Any", "catch", "false", "is", "nil", "rethrows", "super", "self", "Self", "throw", "throws", "true", "try",
		"associativity", "convenience", "dynamic", "didSet", "final", "get", "infix", "indirect", "lazy", "left", "mutating", "none", "nonmutating", "optional", "override", "postfix", "precedence", "prefix", "Protocol", "required", "right", "set", "Type", "unowned", "weak", "willSet"
	]

	private var buffer = ""
	private var linePrefix = ""
	private var linePrefixStack = [String]()


	private func add(content: String) {
		buffer += content
	}


	private func addIdentifier(identifier: String) {
		if Writer.swiftKeywords.contains(identifier) {
			buffer += "`"
			buffer += identifier
			buffer += "`"
		}
		else {
			buffer += identifier
		}
	}


	private func line(line: String = "") {
		if !line.isEmpty {
			buffer += linePrefix
			buffer += line
		}

		buffer += "\n"
	}


	private func line(@noescape closure: Closure) {
		buffer += linePrefix
		closure()
		buffer += "\n"
	}


	private func indent(@noescape closure: Closure) {
		linePrefixStack.append(linePrefix)
		linePrefix += "\t"
		closure()
		linePrefix = linePrefixStack.removeLast()
	}
}
