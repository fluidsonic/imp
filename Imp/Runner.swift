import Commander
import Foundation
import JetPack


public class Runner: NSObject {

	public static func run() {
		let destinationOption = Option("destination", DestinationOption.console, flag: "o", description: "Path of the file to write the generated code to (defaults to 'console').")
		let generatorOption = Option("generator", GeneratorOption.swift2, flag: "g", description: "What generator to use for emitting the generated code (available generators: swift2, swift3).")
		let emitsAttributedTemplatesFlag = Flag("emit-attributed-templates", description: "Whether to emit additional template functions which use attributed strings.", default: true)
		let emitsJetPackImportFlag = Flag("emit-jetpack-import", description: "Whether to emit 'import JetPack' in the generated code when using pluralized strings.", default: true)
		let tableNameOption = Option("tableName", "", description: "Whether to use a specific table name when emitting generated code.")
		let typeNameOption = Option("typeName", "Strings", description: "How the type should be named which contains all strings and namespaces.")
		let visibilityOption = Option("visibility", SwiftStringsGenerator.Visibility.internalVisibility, description: "Visibility the type should have which contains all strings and namespaces (internal or public).")
		let inputFileArgument = Argument<String>("input", description: "Path to the .strings file to be parsed.")

		let stringsCommand = command(
			destinationOption,
			generatorOption,
			emitsAttributedTemplatesFlag,
			emitsJetPackImportFlag,
			tableNameOption,
			typeNameOption,
			visibilityOption,
			inputFileArgument
		) {
			destinationOption,
			generatorOption,
			emitsAttributedTemplates,
			emitsJetPackImport,
			tableName,
			typeName,
			visibility,
			inputFile
			in

			guard let data = try? Data(contentsOf: URL(fileURLWithPath: inputFile)) else {
				throw Error(message: "Cannot load contents of file '\(inputFile)'")
			}

			let parser = StringsParser()
			let items = try parser.parse(data: data)
			let strings = try parser.makeHierarchical(items)
			let skeleton = parser.makeSkeleton(of: strings)

			let generator: StringsGenerator
			switch generatorOption {
			case .swift2, .swift3:
				generator = SwiftStringsGenerator(
					version:                  generatorOption == .swift2 ? .swift2 : .swift3,
					typeName:                 typeName,
					visibility:               visibility,
					tableName:                tableName.nonEmpty,
					emitsAttributedTemplates: emitsAttributedTemplates,
					emitsJetPackImport:       emitsJetPackImport
				)
			}

			let output = generator.generate(for: skeleton)
			try destinationOption.write(output)
		}

		let main = Group {
			$0.addCommand("strings", "Parses a .strings file and generates code to easily access the contents of the file.", stringsCommand)
		}

		main.run("Imp 0.1")
	}



	fileprivate struct Error: CustomStringConvertible, Swift.Error {

		var message: String


		var description: String {
			return message
		}
	}
}



private enum GeneratorOption: ArgumentConvertible {

	case swift2
	case swift3


	init(parser: ArgumentParser) throws {
		guard let rawValue = parser.shift() else {
			throw ArgumentError.missingValue(argument: nil)
		}

		switch rawValue {
		case "swift2": self = .swift2
		case "swift3": self = .swift3
		default:
			throw Runner.Error(message: "Unknown generator '\(rawValue)'. Available generators: swift2")
		}
	}


	var description: String {
		switch self {
		case .swift2: return "Swift 2.3"
		case .swift3: return "Swift 3"
		}
	}
}



private enum DestinationOption: ArgumentConvertible {

	case console
	case file(URL)


	init(parser: ArgumentParser) throws {
		guard let path = parser.shift() else {
			throw ArgumentError.missingValue(argument: nil)
		}

		if path == "console" {
			self = .console
		}
		else {
			self = .file(URL(fileURLWithPath: path))
		}
	}


	var description: String {
		switch self {
		case .console:        return "console"
		case let .file(path): return path.path
		}
	}


	func write(_ content: String) throws {
		switch self {
		case .console:
			print(content)

		case let .file(path):
			// FIXME prevent unnecessary writes

			let data = content.data(using: .utf8, allowLossyConversion: true)!
			try data.write(to: path, options: .atomicWrite)
		}
	}
}


extension SwiftStringsGenerator.Visibility: ArgumentConvertible {

	public init(parser: ArgumentParser) throws {
		guard let rawValue = parser.shift() else {
			throw ArgumentError.missingValue(argument: nil)
		}

		switch rawValue {
		case "internal": self = .internalVisibility
		case "public":   self = .publicVisibility
		default:         throw Runner.Error(message: "Unknown visibility '\(rawValue)'")
		}
	}


	public var description: String {
		switch self {
		case .internalVisibility: return "internal"
		case .publicVisibility:   return "public"
		}
	}
}
