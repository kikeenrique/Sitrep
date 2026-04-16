//
// Extensions.swift
// Part of Sitrep, a tool for analyzing Swift projects.
//
// Copyright (c) 2020 Hacking with Swift
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See LICENSE for license information
//

import Foundation

extension Array {
    /// Counts how many items in an array match a predicate
    func sum(where predicate: (Element) throws -> Bool) rethrows -> Int {
        var total = 0

        for item in self {
            if try predicate(item) {
                total += 1
            }
        }

        return total
    }
}

extension String {
    /// An array of lines in this string, created by splitting on line breaks
    var lines: [String] {
        components(separatedBy: "\n")
    }

    /// BodyStripper removes all comments and most whitespace, but it doesn't collapse multiple
    /// repeating instances do line breaks. This method does that clean up work.
    func removingDuplicateLineBreaks() -> String {
        let strippedLines = self.lines
        let nonEmptyLines = strippedLines.filter { $0.isEmpty == false }
        return nonEmptyLines.joined(separator: "\n")
    }
}

extension Collection where Element == Type {
    /// Returns filtered types which are extended by provided type names
    func extending(from typeNames: [String]) -> [Element] {
        let descendants = descendants()
        return typeNames.flatMap { extending(from: $0, descendants: descendants) }
    }
    
    /// Returns filtered types which are extended by provided type name
    func extending(from typeName: String, descendants: [String: String]) -> [Element] {
        return filter { $0.extends(from: typeName, descendants: descendants) }
    }
    
    /// Returns a map with all possible descendants in the collection
    func descendants() -> [String: String] {
        var map = [String: String]()
        for type in self {
            guard let inheritance = type.inheritance.first else { continue }
            map[type.name] = inheritance
        }
        return map
    }
}

private extension Type {
    /// Checks whether the type is extended by the `typeName` by looking into all descendants
    func extends(from typeName: String, descendants: [String: String]) -> Bool {
        var current: String? = name
        var visited = Set<String>()
        
        while let name = current {
            if visited.contains(name) { return false }
            visited.insert(name)
           
            if name == typeName { return true }
            current = descendants[name]
        }
        
        return false
    }
}

