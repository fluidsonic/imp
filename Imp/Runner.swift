import Commander
import Foundation
import JetPack


public class Runner: NSObject {

	public static func run() {
		let destinationOption = Option("destination", DestinationOption.console, flag: "o", description: "Path of the file to write the generated code to (defaults to 'console').")
		let generatorOption = Option("generator", GeneratorOption.swift2, flag: "g", description: "What generator to use for emitting the generated code (available generators: swift2).")
		let inputFileArgument = Argument<String>("input", description: "Path to the .strings file to be parsed.")

		let stringsCommand = command(destinationOption, generatorOption, inputFileArgument) { destinationOption, generatorOption, inputFile in
			guard let data = NSData(contentsOfFile: inputFile) else {
				throw Error(message: "Cannot load contents of file '\(inputFile)'")
			}

			let parser = StringsParser()
			let items = try parser.parse(data: data)
			let strings = try parser.makeHierarchical(items)
			let skeleton = parser.makeSkeleton(of: strings)

			let generator: StringsGenerator
			switch generatorOption {
			case .swift2: generator = SwiftStringsGenerator(typeName: "Strings", visibility: .internalVisibility)
			}

			let output = generator.generate(for: skeleton)
			try destinationOption.write(output)
		}

		let main = Group {
			$0.addCommand("strings", "Parses a .strings file and generates code to easily access the contents of the file.", stringsCommand)
		}

		main.run("Imp 0.1", arguments: NSProcessInfo.processInfo().arguments)
	}



	private struct Error: ErrorType {

		private var message: String
	}
}



private enum GeneratorOption: ArgumentConvertible {

	case swift2


	private init(parser: ArgumentParser) throws {
		guard let rawValue = parser.shift() else {
			throw ArgumentError.MissingValue(argument: nil)
		}
		guard rawValue == "swift2" else {
			throw Runner.Error(message: "Unknown generator '\(rawValue)'. Available generators: swift2")
		}

		self = .swift2
	}


	private var description: String {
		switch self {
		case .swift2: return "Swift 2.3"
		}
	}
}



private enum DestinationOption: ArgumentConvertible {

	case console
	case file(NSURL)


	private init(parser: ArgumentParser) throws {
		guard let path = parser.shift() else {
			throw ArgumentError.MissingValue(argument: nil)
		}

		if path == "console" {
			self = .console
		}
		else {
			self = .file(NSURL(fileURLWithPath: path))
		}
	}


	private var description: String {
		switch self {
		case .console:        return "console"
		case let .file(path): return path.path ?? "?"
		}
	}


	private func write(content: String) throws {
		switch self {
		case .console:
			print(content)

		case let .file(path):
			// FIXME prevent unnecessary writes

			let data = content.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!
			try data.writeToURL(path, options: .AtomicWrite)
		}
	}
}
