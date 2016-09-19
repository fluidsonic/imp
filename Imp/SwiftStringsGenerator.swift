import Foundation
import JetPack


public struct SwiftStringsGenerator: StringsGenerator {

	private let typeName: String
	private let visibility: String


	public init(typeName: String, visibility: Visibility) {
		self.typeName = typeName

		switch visibility {
		case .internalVisibility: self.visibility = "internal"
		case .publicVisibility:   self.visibility = "public"
		}
	}


	public func generate(for skeleton: StringsSkeleton) -> String {
		let buffer = StrongReference("")

		if namespaceUsesPluralizedStrings(skeleton.rootNamespace) {
			buffer.target += "import JetPack"
		}
		else {
			buffer.target += "import Foundation"
		}
		buffer.target += "\n\n"

		generate(for: skeleton.rootNamespace, buffer: buffer, parentKeyPath: [], lastKeyComponent: nil, linePrefix: "")

		return buffer.target
	}


	private func generate(for namespace: StringsSkeleton.Namespace, buffer: StrongReference<String>, parentKeyPath: KeyPath, lastKeyComponent: KeyComponent?, linePrefix: String) {
		func write(content: String) {
			buffer.target += content
		}

		var nestedLinePrefix = linePrefix
		var nestedLinePrefixStack = [String]()

		func writeLine(line: String = "") {
			if !line.isEmpty {
				buffer.target += nestedLinePrefix
				buffer.target += line
			}
			buffer.target += "\n"
		}

		func writeNested(@noescape closure: Closure) {
			nestedLinePrefixStack.append(nestedLinePrefix)
			nestedLinePrefix += "\t"
			closure()
			nestedLinePrefix = nestedLinePrefixStack.removeLast()
		}


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

		writeLine()
		writeLine("\(visibility) enum `\(enumName)` {")

		let childLinePrefix = "\(linePrefix)\t"

		for (keyComponent, namespace) in namespace.namespaces {
			generate(for: namespace, buffer: buffer, parentKeyPath: keyPath, lastKeyComponent: keyComponent, linePrefix: childLinePrefix)
		}

		if !namespace.items.isEmpty {
			writeLine()
		}

		for (keyComponent, item) in namespace.items {
			generate(for: item, buffer: buffer, parentKeyPath: keyPath, lastKeyComponent: keyComponent, linePrefix: childLinePrefix)
		}

		if lastKeyComponent == nil {
			writeLine()
			writeLine()

			writeNested() {
				writeLine("private static let __bundle: NSBundle = {")
				writeNested() {
					writeLine("class Dummy {}")
					writeLine()
					writeLine("return NSBundle(forClass: Dummy.self)")
				}
				writeLine("}()")

				writeLine()
				writeLine()

				writeLine("private static func __get(key: String) -> String? {")
				writeNested() {
					writeLine("let value = __bundle.localizedStringForKey(key, value: \"\\u{0}\", table: nil)")
					writeLine("guard value != \"\\u{0}\" else {")
					writeNested() {
						writeLine("return nil")
					}
					writeLine("}")
					writeLine("")
					writeLine("return value")
				}
				writeLine("}")

				writeLine()
				writeLine()

				writeLine("private static func __getTemplate(key: String, parameters: [String : String]) -> String {")
				writeNested() {
					writeLine("guard let value = __get(key) else {")
					writeNested() {
						writeLine("return key")
					}
					writeLine("}")
					writeLine("")
					writeLine("return __substituteTemplateParameters(value, parameters: parameters)")
				}
				writeLine("}")

				writeLine()
				writeLine()

				writeLine("private static func __getWithFallback(key: String) -> String {")
				writeNested() {
					writeLine("return __bundle.localizedStringForKey(key, value: key, table: nil)")
				}
				writeLine("}")

				writeLine()
				writeLine()

				writeLine("private static func __substituteTemplateParameters(template: String, parameters: [String : String]) -> String {")
				writeNested() {
					writeLine("var result = \"\"")
					writeLine()
					writeLine("var currentParameter = \"\"")
					writeLine("var isParsingParameter = false")
					writeLine("var isAwaitingClosingCurlyBracket = false")
					writeLine()
					writeLine("for character in template.characters {")
					writeNested() {
						writeLine("if isAwaitingClosingCurlyBracket && character != \"}\" {")
						writeNested() {
							writeLine("return template")
						}
						writeLine("}")
						writeLine()
						writeLine("switch character {")
						writeLine("case \"{\":")
						writeNested() {
							writeLine("if isParsingParameter {")
							writeNested() {
								writeLine("if !currentParameter.isEmpty {")
								writeNested() {
									writeLine("return template")
								}
								writeLine("}")
								writeLine()
								writeLine("isParsingParameter = false")
								writeLine("result += \"{\"")
							}
							writeLine("}")
							writeLine("else {")
							writeNested() {
								writeLine("isParsingParameter = true")
							}
							writeLine("}")
						}
						writeLine()
						writeLine("case \"}\":")
						writeNested() {
							writeLine("if isParsingParameter {")
							writeNested() {
								writeLine("if currentParameter.isEmpty {")
								writeNested() {
									writeLine("return template")
								}
								writeLine("}")
								writeLine()
								writeLine("result += parameters[currentParameter] ?? \"{\\(currentParameter)}\"")
								writeLine("currentParameter = \"\"")
								writeLine("isParsingParameter = false")
							}
							writeLine("}")
							writeLine("else if isAwaitingClosingCurlyBracket {")
							writeNested() {
								writeLine("isAwaitingClosingCurlyBracket = false")
							}
							writeLine("}")
							writeLine("else {")
							writeNested() {
								writeLine("result += \"}\"")
								writeLine("isAwaitingClosingCurlyBracket = true")
							}
							writeLine("}")
						}
						writeLine()
						writeLine("default:")
						writeNested() {
							writeLine("if isParsingParameter {")
							writeNested() {
								writeLine("currentParameter.append(character)")
							}
							writeLine("}")
							writeLine("else {")
							writeNested() {
								writeLine("result.append(character)")
							}
							writeLine("}")
						}
						writeLine("}")
					}
					writeLine("}")
					writeLine()
					writeLine("guard !isParsingParameter && !isAwaitingClosingCurlyBracket else {")
					writeNested() {
						writeLine("return template")
					}
					writeLine("}")
					writeLine()
					writeLine("return result")
				}
				writeLine("}")
			}


			if namespaceUsesPluralizedStrings(namespace) {
				writeLine()
				writeLine()
				writeLine()

				writeNested() {
					writeLine("\(visibility) struct PluralizedString {")
					writeNested() {
						writeLine()
						writeLine("private var converter: ((String) -> String)?")
						writeLine("private var key: String")

						writeLine()
						writeLine()

						writeLine("private init(key: String, converter: ((String) -> String)? = nil) {")
						writeNested() {
							writeLine("self.converter = converter")
							writeLine("self.key = key")
						}
						writeLine("}")

						writeLine()
						writeLine()

						writeLine("\(visibility) func forCategory(category: NSLocale.PluralCategory) -> String {")
						writeNested() {
							writeLine("let keySuffix = keySuffixForCategory(category)")
							writeLine()
							writeLine("guard var value = `\(typeName)`.__get(\"\\(key)\\(keySuffix)\") ?? `\(typeName)`.__get(\"\\(key)$other\") else {")
							writeNested() {
								writeLine("return \"\\(key)$other\"")
							}
							writeLine("}")
							writeLine()
							writeLine("if let converter = converter {")
							writeNested() {
								writeLine("value = converter(value)")
							}
							writeLine("}")
							writeLine()
							writeLine("return value")
						}
						writeLine("}")

						writeLine()
						writeLine()

						writeLine("private func keySuffixForCategory(category: NSLocale.PluralCategory) -> String {")
						writeNested() {
							writeLine("switch category {")
							writeLine("case .few:   return \"$few\"")
							writeLine("case .many:  return \"$many\"")
							writeLine("case .one:   return \"$one\"")
							writeLine("case .other: return \"$other\"")
							writeLine("case .two:   return \"$two\"")
							writeLine("case .zero:  return \"$zero\"")
							writeLine("}")
						}
						writeLine("}")
					}
					writeLine("}")
				}
			}
		}

		writeLine("}")

		if lastKeyComponent != nil {
			writeLine()
		}
	}


	private func generate(for item: StringsSkeleton.Item, buffer: StrongReference<String>, parentKeyPath: KeyPath, lastKeyComponent: KeyComponent, linePrefix: String) {
		switch item {
		case let .pluralized(value, pluralCategories):
			generate(for: value, pluralCategories: pluralCategories, buffer: buffer, parentKeyPath: parentKeyPath, lastKeyComponent: lastKeyComponent, linePrefix: linePrefix)

		case let .simple(value):
			generate(for: value, pluralCategories: nil, buffer: buffer, parentKeyPath: parentKeyPath, lastKeyComponent: lastKeyComponent, linePrefix: linePrefix)
		}
	}


	private func generate(for value: StringsSkeleton.Value, pluralCategories: Set<NSLocale.PluralCategory>?, buffer: StrongReference<String>, parentKeyPath: KeyPath, lastKeyComponent: KeyComponent, linePrefix: String) {
		func writeKeyPath() {
			if !parentKeyPath.isEmpty {
				for component in parentKeyPath {
					buffer.target += component.value
					buffer.target += "."
				}
			}

			buffer.target += lastKeyComponent.value
		}


		let returnType = pluralCategories != nil ? "PluralizedString" : "String"

		switch value {
		case .constant:
			buffer.target += linePrefix
			buffer.target += visibility
			buffer.target += " static var `"
			buffer.target += lastKeyComponent.value
			buffer.target += "`: "
			buffer.target += returnType
			buffer.target += " { return "

			if pluralCategories == nil {
				buffer.target += "`"
				buffer.target += typeName
				buffer.target += "`.__getWithFallback(\""
				writeKeyPath()
				buffer.target += "\")"
			}
			else {
				buffer.target += "PluralizedString(key: \""
				writeKeyPath()
				buffer.target += "\")"
			}

			buffer.target += " }\n"

		case let .template(parameterNames):
			func writeParameterDictionary() {
				buffer.target += "["
				for (index, parameterName) in parameterNames.enumerate() {
					if index > 0 {
						buffer.target += ", "
					}

					buffer.target += "\""
					buffer.target += parameterName.value
					buffer.target += "\": `"
					buffer.target += parameterName.value
					buffer.target += "`"
				}
				buffer.target += "]"
			}

			buffer.target += linePrefix
			buffer.target += visibility
			buffer.target += " static func `"
			buffer.target += lastKeyComponent.value
			buffer.target += "`("

			for (index, parameterName) in parameterNames.enumerate() {
				if index == 0 {
					buffer.target += "`"
					buffer.target += parameterName.value
					buffer.target += "` "
				}
				else {
					buffer.target += ", "
				}

				buffer.target += "`"
				buffer.target += parameterName.value
				buffer.target += "`: String"
			}

			buffer.target += ") -> "
			buffer.target += returnType
			buffer.target += " {\n"

			if pluralCategories == nil {
				buffer.target += linePrefix
				buffer.target += "\treturn `"
				buffer.target += typeName
				buffer.target += "`.__getTemplate(\""
				writeKeyPath()
				buffer.target += "\", parameters: "
				writeParameterDictionary()
				buffer.target += ")\n"
			}
			else {
				buffer.target += linePrefix
				buffer.target += "\tlet __parameters: [String : String] = "
				writeParameterDictionary()
				buffer.target += "\n"

				buffer.target += linePrefix
				buffer.target += "\treturn PluralizedString(key: \""
				writeKeyPath()
				buffer.target += "\") { (template: String) -> String in\n"

				buffer.target += linePrefix
				buffer.target += "\t\treturn `"
				buffer.target += typeName
				buffer.target += "`.__substituteTemplateParameters(template, parameters: __parameters)\n"

				buffer.target += linePrefix
				buffer.target += "\t}\n"
			}

			buffer.target += linePrefix
			buffer.target += "}\n"
		}
	}


	private func namespaceUsesPluralizedStrings(namespace: StringsSkeleton.Namespace) -> Bool {
		for case .pluralized in namespace.items.values {
			return true
		}
		for namespace in namespace.namespaces.values where namespaceUsesPluralizedStrings(namespace) {
			return true
		}

		return false
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
