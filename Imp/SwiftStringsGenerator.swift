import Foundation
import JetPack


public struct SwiftStringsGenerator: StringsGenerator {

	private let attributeStringKeyType: String
	private let emitsAttributedTemplates: Bool
	private let emitsJetPackImport: Bool
	private let tableName: String?
	private let typeName: String
	private let version: Version
	private let visibility: String


	public init(
		version: Version = .swift4,
		typeName: String = "Strings",
		visibility: Visibility = .internalVisibility,
		tableName: String? = nil,
		emitsAttributedTemplates: Bool = true,
		emitsJetPackImport: Bool = true
	) {
		self.attributeStringKeyType = version == .swift3 ? "String" : "NSAttributedStringKey"
		self.emitsAttributedTemplates = emitsAttributedTemplates
		self.emitsJetPackImport = emitsJetPackImport
		self.tableName = tableName
		self.typeName = typeName
		self.version = version

		switch visibility {
		case .internalVisibility: self.visibility = "internal"
		case .publicVisibility:   self.visibility = "public"
		}
	}


	public func generate(for skeleton: StringsSkeleton) -> String {
		let emitsPluralizedStrings = self.skeletonUsesPluralizedStrings(skeleton)
		let writer = Writer(version: version)

		writer.line("import Foundation")
		if emitsJetPackImport && emitsPluralizedStrings {
			writer.line("import JetPack")
		}
		writer.line()

		generate(for: skeleton.rootNamespace, writer: writer, parentKeyPath: [], lastKeyComponent: nil)

		let tableName = self.tableName.map({ "\"\($0)\"" }) ?? "nil"

		writer.line()
		writer.line()
		writer.line()

		writer.line("private let __bundle: Bundle = {")
		writer.indent() {
			writer.line("class Dummy {}")
			writer.line()
			writer.line("return Bundle(for: Dummy.self)")
		}
		writer.line("}()")

		if emitsPluralizedStrings {
			writer.line()
			writer.line()

			writer.line("private let __defaultFormatter: NumberFormatter = {")
			writer.indent() {
				writer.line("let formatter = NumberFormatter()")
				writer.line("formatter.locale = Locale.autoupdatingCurrent")
				writer.line("formatter.numberStyle = .decimal")
				writer.line()
				writer.line("return formatter")
			}
			writer.line("}()")

			writer.line()
			writer.line()

			writer.function(name: "__keySuffix", visibility: "private", firstParameterExternalName: "for", parameters: "category: Locale.PluralCategory", returnType: "String") {
				writer.line("switch category {")
				writer.line("case .few:   return \"$few\"")
				writer.line("case .many:  return \"$many\"")
				writer.line("case .one:   return \"$one\"")
				writer.line("case .other: return \"$other\"")
				writer.line("case .two:   return \"$two\"")
				writer.line("case .zero:  return \"$zero\"")
				writer.line("}")
			}
		}

		writer.line()
		writer.line()

		writer.function(name: "__string", visibility: "private", parameters: "key: String, parameters: [String : String]? = nil", returnType: "String") {
			writer.line("return __tryString(key).map { __substituteTemplateParameters(template: $0, parameters: parameters) } ?? key")
		}

		if emitsAttributedTemplates {
			writer.line()
			writer.line()

			writer.function(name: "__string", visibility: "private", parameters: "key: String, parameters: [String : NSAttributedString]", returnType: "NSAttributedString") {
				writer.line("return __tryString(key).map { __substituteTemplateParameters(template: $0, parameters: parameters) } ?? NSAttributedString(string: key)")
			}
		}

		if emitsPluralizedStrings {
			writer.line()
			writer.line()

			writer.function(name: "__string", visibility: "private", parameters: "key: String, pluralCategory: Locale.PluralCategory, parameters: [String : String]?", returnType: "String") {
				writer.line("guard let template = __tryString(key, pluralCategory: pluralCategory) else {")
				writer.indent() {
					writer.line("return key")
				}
				writer.line("}")
				writer.line()
				writer.line("return __substituteTemplateParameters(template: template, parameters: parameters)")
			}

			if emitsAttributedTemplates {
				writer.line()
				writer.line()

				writer.function(name: "__string", visibility: "private", parameters: "key: String, pluralCategory: Locale.PluralCategory, parameters: [String : NSAttributedString]?", returnType: "NSAttributedString") {
					writer.line("guard let template = __tryString(key, pluralCategory: pluralCategory) else {")
					writer.indent() {
						writer.line("return NSAttributedString(string: key)")
					}
					writer.line("}")
					writer.line()
					writer.line("return __substituteTemplateParameters(template: template, parameters: parameters)")
				}
			}

			writer.line()
			writer.line()

			writer.function(name: "__string", visibility: "private", parameters: "key: String, number: NSNumber, formatter: NumberFormatter, parameters: [String : String]?", returnType: "String") {
				writer.line("return __string(key, pluralCategory: Locale.current.pluralCategoryForNumber(number, formatter: formatter), parameters: parameters)")
			}

			if emitsAttributedTemplates {
				writer.line()
				writer.line()

				writer.function(name: "__string", visibility: "private", parameters: "key: String, number: NSNumber, formatter: NumberFormatter, parameters: [String : NSAttributedString]?", returnType: "NSAttributedString") {
					writer.line("return __string(key, pluralCategory: Locale.current.pluralCategoryForNumber(number, formatter: formatter), parameters: parameters)")
				}
			}
		}

		writer.line()
		writer.line()

		writer.function(name: "__substituteTemplateParameters", visibility: "private", firstParameterExternalName: "template", parameters: "template: String, parameters: [String : String]?", returnType: "String") {
			writer.line("guard let parameters = parameters else {")
			writer.indent() {
				writer.line("return template")
			}
			writer.line("}")
			writer.line()
			writer.line("var result = \"\"")
			writer.line("return __substituteTemplateParameters(")
			writer.indent() {
				writer.line("template:    template,")
				writer.line("onCharacter: { result.append($0) },")
				writer.line("onParameter: { result += parameters[$0] ?? \"{\\($0)}\" }")
			}
			writer.line(") ? result : template")
		}

		if emitsAttributedTemplates {
			writer.line()
			writer.line()

			writer.function(name: "__substituteTemplateParameters", visibility: "private", firstParameterExternalName: "template", parameters: "template: String, parameters: [String : NSAttributedString]?", returnType: "NSAttributedString") {
				writer.line("guard let parameters = parameters else {")
				writer.indent() {
					writer.line("return NSAttributedString(string: template)")
				}
				writer.line("}")
				writer.line()
				writer.line("let result = NSMutableAttributedString()")
				writer.line("var currentConstant = \"\"")
				writer.line()
				writer.line("let success = __substituteTemplateParameters(")
				writer.indent() {
					writer.line("template:    template,")
					writer.line("onCharacter: { currentConstant.append($0) },")
					writer.line("onParameter: { parameterName in")
					writer.indent() {
						writer.line("if !currentConstant.isEmpty {")
						writer.indent() {
							writer.line("result.append(NSAttributedString(string: currentConstant))")
							writer.line("currentConstant = \"\"")
						}
						writer.line("}")
						writer.line()
						writer.line("result.append(parameters[parameterName] ?? NSAttributedString(string: \"{\\(parameterName)}\"))")
					}
					writer.line("}")
				}
				writer.line(")")
				writer.line("guard success else {")
				writer.indent() {
					writer.line("return NSAttributedString(string: template)")
				}
				writer.line("}")
				writer.line()
				writer.line("if !currentConstant.isEmpty {")
				writer.indent() {
					writer.line("result.append(NSAttributedString(string: currentConstant))")
				}
				writer.line("}")
				writer.line()
				writer.line("return result")
			}
		}

		writer.line()
		writer.line()

		writer.function(name: "__substituteTemplateParameters", visibility: "private", firstParameterExternalName: "template", parameters: "template: String, onCharacter: (Character) -> Void, onParameter: (String) -> Void", returnType: "Bool") {
			writer.line("var currentParameter = \"\"")
			writer.line("var isParsingParameter = false")
			writer.line("var isAwaitingClosingCurlyBracket = false")
			writer.line()
			writer.line("for character in template.characters {")
			writer.indent() {
				writer.line("if isAwaitingClosingCurlyBracket && character != \"}\" {")
				writer.indent() {
					writer.line("return false")
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
							writer.line("return false")
						}
						writer.line("}")
						writer.line()
						writer.line("isParsingParameter = false")
						writer.line("onCharacter(\"{\")")
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
							writer.line("return false")
						}
						writer.line("}")
						writer.line()
						writer.line("onParameter(currentParameter)")
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
						writer.line("onCharacter(\"}\")")
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
						writer.line("onCharacter(character)")
					}
					writer.line("}")
				}
				writer.line("}")
			}
			writer.line("}")
			writer.line()
			writer.line("guard !isParsingParameter && !isAwaitingClosingCurlyBracket else {")
			writer.indent() {
				writer.line("return false")
			}
			writer.line("}")
			writer.line()
			writer.line("return true")
		}

		writer.line()
		writer.line()

		writer.function(name: "__tryString", visibility: "private", parameters: "key: String", returnType: "String?") {
			writer.line("let value = __bundle.localizedString(forKey: key, value: \"\\u{0}\", table: \(tableName))")
			writer.line("guard value != \"\\u{0}\" else {")
			writer.indent() {
				writer.line("return nil")
			}
			writer.line("}")
			writer.line("")
			writer.line("return value")
		}

		if emitsPluralizedStrings {
			writer.line()
			writer.line()

			writer.function(name: "__tryString", visibility: "private", parameters: "key: String, pluralCategory: Locale.PluralCategory", returnType: "String?") {
				writer.line("let keySuffix = __keySuffix(for: pluralCategory)")
				writer.line("return __tryString(\"\\(key)\\(keySuffix)\") ?? __tryString(\"\\(key)$other\")")
			}

			if emitsAttributedTemplates {
				writer.line()
				writer.line()
				writer.line()

				writer.line("fileprivate struct __PluralizedAttributedString: PluralizedAttributedString {")
				writer.indent() {
					writer.line()
					writer.line("private var key: String")
					writer.line("private var parameters: [String : NSAttributedString]")

					writer.line()
					writer.line()

					writer.initializer(visibility: "fileprivate", parameters: "_ key: String, parameters: [String : NSAttributedString]") {
						writer.line("self.key = key")
						writer.line("self.parameters = parameters")
					}

					writer.line()
					writer.line()

					writer.function(name: "forPluralCategory", visibility: "fileprivate", parameters: "pluralCategory: Locale.PluralCategory", returnType: "NSAttributedString") {
						writer.line("return __string(key, pluralCategory: pluralCategory, parameters: parameters)")
					}
				}
				writer.line("}")
			}

			writer.line()
			writer.line()
			writer.line()

			writer.line("fileprivate struct __PluralizedString: PluralizedString {")
			writer.indent() {
				writer.line()
				writer.line("private var key: String")
				writer.line("private var parameters: [String : String]?")

				writer.line()
				writer.line()

				writer.initializer(visibility: "fileprivate", parameters: "_ key: String, parameters: [String : String]? = nil") {
					writer.line("self.key = key")
					writer.line("self.parameters = parameters")
				}

				writer.line()
				writer.line()

				writer.function(name: "forPluralCategory", visibility: "fileprivate", parameters: "pluralCategory: Locale.PluralCategory", returnType: "String") {
					writer.line("return __string(key, pluralCategory: pluralCategory, parameters: parameters)")
				}
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
			for (keyComponent, namespace) in namespace.namespaces.sorted(by: { $0.0 < $1.0 }) {
				generate(for: namespace, writer: writer, parentKeyPath: keyPath, lastKeyComponent: keyComponent)
			}
			for (keyComponent, item) in namespace.items.sorted(by: { $0.0 < $1.0 }) {
				generate(for: item, writer: writer, parentKeyPath: keyPath, lastKeyComponent: keyComponent)
			}
		}
		writer.line("}")

		if lastKeyComponent != nil {
			writer.line()
		}
	}


	private func generate(for item: StringsSkeleton.Item, writer: Writer, parentKeyPath: KeyPath, lastKeyComponent: KeyComponent) {
		func next(for value: StringsSkeleton.Value, pluralCategories: Set<Locale.PluralCategory>? = nil, keyTemplateParameterName: ParameterName? = nil) {
			generate(for: value, pluralCategories: pluralCategories, keyTemplateParameterName: keyTemplateParameterName, writer: writer, parentKeyPath: parentKeyPath, lastKeyComponent: lastKeyComponent)
		}

		switch item {
		case let .pluralized(value, pluralCategories, keyTemplateParameterName):
			next(for: value, pluralCategories: pluralCategories, keyTemplateParameterName: keyTemplateParameterName)

		case let .simple(value):
			next(for: value)
		}
	}


	private func generate(for value: StringsSkeleton.Value, pluralCategories: Set<Locale.PluralCategory>?, keyTemplateParameterName: ParameterName?, writer: Writer, parentKeyPath: KeyPath, lastKeyComponent: KeyComponent) {
		func writeKeyPath() {
			if !parentKeyPath.isEmpty {
				for component in parentKeyPath {
					writer.add(component.value)
					writer.add(".")
				}
			}

			writer.add(lastKeyComponent.value)
		}

		writer.line()

		switch value {
		case .constant:
			let returnType = pluralCategories != nil ? "PluralizedString" : "String"

			writer.line() {
				writer.add(visibility)
				writer.add(" static var ")
				writer.addIdentifier(lastKeyComponent.value)
				writer.add(": ")
				writer.add(returnType)
			}
			writer.indent() {
				writer.line() {
					writer.add("{ return ")

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
			}

		case let .template(parameterNames):
			func writeParameterDictionary(attributed: Bool) {
				writer.add("[")
				for (index, parameterName) in parameterNames.enumerated() {
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
						if attributed {
							writer.add("NSAttributedString(string: ")
						}

						writer.add("formatter.string(for: ")
						writer.addIdentifier(parameterName.value)
						writer.add(") ?? \"\"")
						if attributed {
							writer.add(", attributes: ")
							writer.add(parameterName.value)
							writer.add("Attributes)")
						}
					}
					else {
						writer.addIdentifier(parameterName.value)
					}
				}
				writer.add("]")
			}

			func writeAccessorFunction(attributed: Bool) {
				writer.line() {
					writer.add(visibility)
					writer.add(" static func ")
					writer.addIdentifier(lastKeyComponent.value)
					writer.add("(")

					for (index, parameterName) in parameterNames.enumerated() {
						if index > 0 {
							writer.add(",")
						}
						writer.add(" ")

						writer.addIdentifier(parameterName.value)
						writer.add(": ")

						if parameterName == keyTemplateParameterName {
							writer.add("NSNumber")
							if attributed {
								writer.add(", ")
								writer.add(parameterName.value)
								writer.add("Attributes: [")
								writer.add(attributeStringKeyType)
								writer.add(" : AnyObject]")
							}
						}
						else if attributed {
							writer.add("NSAttributedString")
						}
						else {
							writer.add("String")
						}
					}

					if keyTemplateParameterName != nil {
						writer.add(", formatter: NumberFormatter = __defaultFormatter")
					}

					writer.add(") -> ")
					if pluralCategories == nil || keyTemplateParameterName != nil {
						writer.add(attributed ? "NSAttributedString" : "String")
					}
					else {
						writer.add(attributed ? "PluralizedAttributedString" : "PluralizedString")
					}
				}

				writer.indent() {
					writer.line() {
						writer.add("{ return ")
						if pluralCategories == nil || keyTemplateParameterName != nil {
							writer.add("__string")
						}
						else {
							writer.add(attributed ? "__PluralizedAttributedString" : "__PluralizedString")
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
						writeParameterDictionary(attributed: attributed)

						writer.add(") }")
					}
				}
			}

			writeAccessorFunction(attributed: false)

			if emitsAttributedTemplates && !parameterNames.isEmpty {
				writeAccessorFunction(attributed: true)
			}
		}
	}


	private func skeletonUsesPluralizedStrings(_ skeleton: StringsSkeleton) -> Bool {
		func namespaceUsesPluralizedStrings(_ namespace: StringsSkeleton.Namespace) -> Bool {
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



	public enum Version {

		case swift3
		case swift4
	}



	public enum Visibility {

		case internalVisibility
		case publicVisibility
	}
}



extension String {

	fileprivate var firstCharacterCapitalized: String {
		guard !isEmpty else {
			return self
		}

		let breakpoint = characters.index(startIndex, offsetBy: 1)
		return self[startIndex ..< breakpoint].uppercased() + self[breakpoint ..< endIndex]
	}
}



private final class Writer {

	private static let swiftKeywords: Set<String> = [
		"associatedtype", "class", "deinit", "enum", "extension", "func", "import", "init", "inout", "internal", "let", "operator", "private", "protocol", "public", "static", "struct", "subscript", "typealias", "var",
		"break", "case", "continue", "default", "defer", "do", "else", "fallthrough", "for", "guard", "if", "in", "repeat", "return", "switch", "where", "while",
		"as", "Any", "catch", "false", "is", "nil", "rethrows", "super", "self", "Self", "throw", "throws", "true", "try",
		"associativity", "convenience", "dynamic", "didSet", "final", "get", "infix", "indirect", "lazy", "left", "mutating", "none", "nonmutating", "optional", "override", "postfix", "precedence", "prefix", "Protocol", "required", "right", "set", "Type", "unowned", "weak", "willSet"
	]

	private var linePrefix = ""
	private var linePrefixStack = [String]()
	private let version: SwiftStringsGenerator.Version

	private(set) var buffer = ""


	init(version: SwiftStringsGenerator.Version) {
		self.version = version
	}


	func add(_ content: String) {
		buffer += content
	}


	func addIdentifier(_ identifier: String) {
		if Writer.swiftKeywords.contains(identifier) {
			buffer += "`"
			buffer += identifier
			buffer += "`"
		}
		else {
			buffer += identifier
		}
	}


	func function(name: String, visibility: String, firstParameterExternalName: String? = nil, parameters: String? = nil, returnType: String? = nil, closure: Closure) {
		add(linePrefix)
		add(visibility)
		add(" func ")
		addIdentifier(name)
		add("(")

		switch version {
		case .swift3, .swift4:
			if let firstParameterExternalName = firstParameterExternalName {
				guard let parameters = parameters else {
					preconditionFailure()
				}

				if !parameters.hasPrefix("\(firstParameterExternalName):") {
					addIdentifier(firstParameterExternalName)
					add(" ")
				}
			}
			else if parameters != nil {
				add("_ ")
			}
		}

		if let parameters = parameters {
			add(parameters)
		}

		add(")")

		if let returnType = returnType {
			add(" -> ")
			addIdentifier(returnType)
		}

		add(" {\n")
		indent(closure)
		line("}")
	}


	func initializer(visibility: String, parameters: String? = nil, closure: Closure) {
		add(linePrefix)
		add(visibility)
		add(" init(")

		if let parameters = parameters {
			add(parameters)
		}

		add(") {\n")
		indent(closure)
		line("}")
	}


	func line(_ line: String = "") {
		if !line.isEmpty {
			buffer += linePrefix
			buffer += line
		}

		buffer += "\n"
	}


	func line(_ closure: Closure) {
		buffer += linePrefix
		closure()
		buffer += "\n"
	}


	func indent(_ closure: Closure) {
		linePrefixStack.append(linePrefix)
		linePrefix += "\t"
		closure()
		linePrefix = linePrefixStack.removeLast()
	}
}
