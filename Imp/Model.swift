import Foundation
import JetPack


public struct Key: CustomDebugStringConvertible, CustomStringConvertible, Hashable {

	public var value: String


	public init(_ value: String) {
		self.value = value
	}


	public var debugDescription: String {
		return "Key(\(description))"
	}


	public var description: String {
		return value
	}


	public var hashValue: Int {
		return value.hashValue
	}
}


public func == (a: Key, b: Key) -> Bool {
	return a.value == b.value
}



public struct KeyComponent: Comparable, CustomDebugStringConvertible, CustomStringConvertible, Hashable {

	public var value: String


	public init?(_ value: String) {
		if value.isEmpty || value.contains(".") {
			return nil
		}

		self.value = value
	}


	public var debugDescription: String {
		return "KeyComponent(\(description))"
	}


	public var description: String {
		return value
	}


	public var hashValue: Int {
		return value.hashValue
	}
}


public func < (a: KeyComponent, b: KeyComponent) -> Bool {
	return a.value < b.value
}


public func == (a: KeyComponent, b: KeyComponent) -> Bool {
	return a.value == b.value
}



public struct KeyPath: CustomDebugStringConvertible, CustomStringConvertible, ExpressibleByArrayLiteral, Hashable, MutableCollection {

	public typealias Components = Array<KeyComponent>
	public typealias Element = KeyComponent
	public typealias Index = Components.Index
	public typealias Iterator = Components.Iterator
	public typealias SubSequence = Components.SubSequence

	public var components: [KeyComponent]


	public init(_ components: [KeyComponent]) {
		self.components = components
	}


	public init?(_ key: Key) {
		components = []

		for component in key.value.components(separatedBy: ".") {
			guard let component = KeyComponent(component) else {
				return nil
			}

			components.append(component)
		}
	}


	public init(arrayLiteral elements: KeyComponent...) {
		self.init(elements)
	}


	public var debugDescription: String {
		return "KeyPath(\(description))"
	}


	public var description: String {
		return components.joined(separator: ".") { $0.description }
	}


	public var endIndex: Index {
		return components.endIndex
	}


	public func makeIterator() -> Iterator {
		return components.makeIterator()
	}


	public var hashValue: Int {
		return components.reduce(0) { (a, b) in a ^ b.hashValue }
	}


	public func index(after i: Index) -> Index {
		return components.index(after: i)
	}


	public subscript(index: Index) -> Element {
		get { return components[index] }
		set { components[index] = newValue }
	}


	public subscript(bounds: Range<Index>) -> ArraySlice<Element> {
		get { return components[bounds] }
		set { components[bounds] = newValue }
	}


	public var startIndex: Index {
		return components.startIndex
	}
}


public func == (a: KeyPath, b: KeyPath) -> Bool {
	return a.components == b.components
}


public func + (a: KeyPath, b: KeyPath) -> KeyPath {
	return KeyPath(a.components + b.components)
}


public func + (path: KeyPath, component: KeyComponent) -> KeyPath {
	var path = path
	path.components.append(component)
	return path
}


public func + (component: KeyComponent, path: KeyPath) -> KeyPath {
	var path = path
	path.components.insert(component, at: 0)
	return path
}



public struct ParameterName: CustomDebugStringConvertible, CustomStringConvertible, Hashable {

	public var value: String


	public init(_ value: String) {
		self.value = value
	}


	public var debugDescription: String {
		return "ParameterName(\(description))"
	}


	public var description: String {
		return value
	}


	public var hashValue: Int {
		return value.hashValue
	}
}


public func == (a: ParameterName, b: ParameterName) -> Bool {
	return a.value == b.value
}



public struct Strings {

	public var rootNamespace: Namespace


	public init(rootNamespace: Namespace = Namespace()) {
		self.rootNamespace = rootNamespace
	}
	


	public enum Item {

		case pluralized([Locale.PluralCategory : Value], keyTemplateParameterName: ParameterName?)
		case simple(Value)
	}



	public struct Namespace {

		public var items: [KeyComponent : Item]
		public var namespaces: [KeyComponent : Namespace]


		public init(items: [KeyComponent : Item] = [:], namespaces: [KeyComponent : Namespace] = [:]) {
			self.items = items
			self.namespaces = namespaces
		}
	}



	public enum Value {

		case constant(String)
		case template(components: [TemplateComponent])


		public enum TemplateComponent {

			case constant(String)
			case parameter(name: ParameterName)
		}
	}
}



public struct StringsSkeleton {

	public var rootNamespace: Namespace


	public init(rootNamespace: Namespace = Namespace()) {
		self.rootNamespace = rootNamespace
	}



	public enum Item {

		case pluralized(value: Value, pluralCategories: Set<Locale.PluralCategory>, keyTemplateParameterName: ParameterName?)
		case simple(value: Value)
	}



	public struct Namespace {

		public var items: [KeyComponent : Item]
		public var namespaces: [KeyComponent : Namespace]


		public init(items: [KeyComponent : Item] = [:], namespaces: [KeyComponent : Namespace] = [:]) {
			self.items = items
			self.namespaces = namespaces
		}
	}



	public enum Value {

		case constant
		case template(parameterNames: [ParameterName])
	}
}
