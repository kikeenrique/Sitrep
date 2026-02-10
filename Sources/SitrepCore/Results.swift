//
// Results.swift
// Part of Sitrep, a tool for analyzing Swift projects.
//
// Copyright (c) 2020 Hacking with Swift
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See LICENSE for license information
//

import Foundation

public struct Results {
    /// All the files detected by this scan
    var files: [File]

    /// All the classes detected across all files
    var classes = [Type]()

    /// All the structs detected across all files
    var structs = [Type]()

    /// All the enums detected across all files
    var enums = [Type]()

    /// All the protocols detected across all files
    var protocols = [Type]()

    /// All the extensions detected across all files
    var extensions = [Type]()

    /// All the imports detected across all files, stored with frequency
    var imports = NSCountedSet()

    /// A string containing all code in all files
    var totalCode = ""

    /// A string containing all stripped code in all files
    var totalStrippedCode = ""

    /// The number of lines in the longest file
    var longestFileLength = 0

    /// The File object storing the longest file that was scanned
    var longestFile: File?

    /// The nmber of lines in the longest type
    var longestTypeLength = 0

    /// The Type object storing the longest file that was scanned
    var longestType: Type?

    /// A count of how many functions were detected
    var functionCount = 0

    /// A count of how many functions were preceded by documentation comments
    var documentedFunctionCount = 0

    /// The total number of lines of code scanned across all files
    var totalLinesOfCode: Int {
        totalCode.lines.count
    }

    /// The total number of stripped lines of code scanned across all files
    var totalStrippedLinesOfCode: Int {
        totalStrippedCode.lines.count
    }

    /// How many classes inherit from UIView
    var uiKitViewCount: Int {
        classes.sum { $0.inheritance.first == "UIView" }
    }

    /// How many classes inherit from UIViewController
    var uiKitViewControllerCount: Int {
        classes.sum { $0.inheritance.first == "UIViewController" }
    }

    /// How many structs conform to View
    var swiftUIViewCount: Int {
        structs.sum { $0.inheritance.contains("View") }
    }

    /// The total number of striped lines of code scanned across all files and related to UIKit
    var uiKitLinesOfCode: Int {
        let uiKitClasses: [String] = [
            "UIApplication", "UIWindow", "UINavigationController", "UISplitViewController", "UIViewController", "UIView", "UITableViewController", "UITableView", "UITableViewCell", "UIScrollView", "UIBarButtonItem", "UIBarItem", "UITabBarController", "UITabBarItem", "UIStackView", "UICollectionView", "UICollectionViewCell", "UIButton", "UIControl", "UITextView", "UITextField", "UILabel", "UIPickerView", "UIImageView", "UISwitch", "MKMapView", "MKAnnotationView"
        ]
        let filteredClasses = classes.extending(from: uiKitClasses)
        let classesLinesOfCode = filteredClasses.reduce(0) { result, type in
            return result + type.strippedBody.lines.count
        }
        let portTypes = ["UIViewRepresentable", "UIViewControllerRepresentable"]
        let filteredPorts = structs.filter {
            guard let inheritance = $0.inheritance.first else { return false }
            return portTypes.contains(inheritance)
        }
        let portsLinesOfCode = filteredPorts.reduce(0) { result, type in
            return result + type.strippedBody.lines.count
        }
        let extensionTypes = filteredClasses.map { $0.name } + uiKitClasses + filteredPorts.map { $0.name } + portTypes
        let extensionsLinesOfCode = extensions.reduce(0) { result, type in
            guard extensionTypes.contains(type.name) else { return result }
            return result + type.strippedBody.lines.count
        }
        return classesLinesOfCode + portsLinesOfCode + extensionsLinesOfCode
    }

    /// The total number of striped lines of code scanned across all files and related to SwiftUI
    var swiftUILinesOfCode: Int {
        let viewTypes = structs.filter { $0.inheritance.first == "View" }
        let viewsLinesOfCode = viewTypes.reduce(0) { result, type in
            return result + type.strippedBody.lines.count
        }
        let extensionTypes = viewTypes.map { $0.name } + ["View"]
        let extensionsLinesOfCode = extensions.reduce(0) { result, type in
            guard extensionTypes.contains(type.name) else { return result }
            return result + type.strippedBody.lines.count
        }
        return viewsLinesOfCode + extensionsLinesOfCode
    }
}
