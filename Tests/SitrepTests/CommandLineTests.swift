//
// CommandLineTests.swift
// Part of Sitrep, a tool for analyzing Swift projects.
//
// Copyright (c) 2020 Hacking with Swift
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See LICENSE for license information
//

import XCTest

/// Black-box tests that run the built `sitrep` executable and assert on what it
/// prints.
///
/// SitrepCoreTests covers the analysis itself by calling the library directly.
/// These cover the things only a real process exercises: argument parsing, exit
/// codes, the configuration file being found and decoded, and the directory walk
/// running against a real filesystem rather than the repository's own checkout.
///
/// That last point is why these matter on Linux in particular. `Scan.detectFiles`
/// uses FileManager.enumerator and `hasDirectoryPath`, and configuration decoding
/// goes through Yams' C library — both swift-corelibs-foundation surfaces that no
/// amount of macOS testing exercises.
final class CommandLineTests: XCTestCase {
    // MARK: - Running the binary

    /// The directory holding the built products, including the executable.
    private var productsDirectory: URL {
        #if os(macOS)
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }

        fatalError("couldn't find the products directory")
        #else
        return Bundle.main.bundleURL
        #endif
    }

    private struct Result {
        let standardOutput: String
        let standardError: String
        let exitCode: Int32
    }

    @discardableResult
    private func runSitrep(_ arguments: [String], file: StaticString = #filePath, line: UInt = #line) throws -> Result {
        let binary = productsDirectory.appendingPathComponent("sitrep")

        let process = Process()
        process.executableURL = binary
        process.arguments = arguments

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        try process.run()

        // Read before waiting: a report large enough to fill the pipe buffer would
        // otherwise block the child forever while we wait for it to exit.
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = error.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return Result(
            standardOutput: String(decoding: outputData, as: UTF8.self),
            standardError: String(decoding: errorData, as: UTF8.self),
            exitCode: process.terminationStatus
        )
    }

    // MARK: - Fixtures

    /// Builds a throwaway project tree and returns its URL.
    ///
    /// Deliberately nested, and deliberately containing a non-Swift file: the
    /// recursion and the extension filter are the two parts of the walk most
    /// likely to behave differently between Darwin Foundation and
    /// swift-corelibs-foundation.
    private func makeFixture() throws -> URL {
        // Under .build rather than NSTemporaryDirectory(): on macOS the temporary
        // directory sits below /var, which is a symlink to /private/var, and
        // exclusions are matched as string prefixes of the path passed in while
        // FileManager.enumerator reports the resolved form. A fixture under a
        // symlink would therefore defeat testExcludedDirectoryIsSkipped for
        // reasons having nothing to do with exclusions.
        //
        // (resolvingSymlinksInPath() is not the fix — Foundation strips the
        // /private prefix rather than resolving to it, returning the path
        // unchanged.)
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // SitrepTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root
        let root = packageRoot
            .appendingPathComponent(".build/test-fixtures")
            .appendingPathComponent("SitrepTests-\(UUID().uuidString)")
        let nested = root.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }

        try """
        import Foundation

        class Alpha {
            func go() {
                print("hi")
            }
        }
        """.write(to: root.appendingPathComponent("top.swift"), atomically: true, encoding: .utf8)

        try """
        import Foundation

        struct Beta {}

        enum Gamma { case a }

        protocol Delta {}
        """.write(to: nested.appendingPathComponent("deep.swift"), atomically: true, encoding: .utf8)

        try "not swift"
            .write(to: nested.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        return root
    }

    // MARK: - Reporting

    func testScansNestedDirectoriesAndIgnoresNonSwiftFiles() throws {
        let fixture = try makeFixture()
        let result = try runSitrep(["--path", fixture.path])

        XCTAssertEqual(result.exitCode, 0, result.standardError)
        // Two, not one: the walk recursed into nested/. Two, not three: notes.txt
        // was filtered out by extension.
        XCTAssertTrue(result.standardOutput.contains("Files scanned: 2"), result.standardOutput)
        XCTAssertTrue(result.standardOutput.contains("Classes: 1"), result.standardOutput)
        XCTAssertTrue(result.standardOutput.contains("Structs: 1"), result.standardOutput)
        XCTAssertTrue(result.standardOutput.contains("Enums: 1"), result.standardOutput)
        XCTAssertTrue(result.standardOutput.contains("Protocols: 1"), result.standardOutput)
    }

    func testJSONReportIsWellFormed() throws {
        let fixture = try makeFixture()
        let result = try runSitrep(["--path", fixture.path, "--format", "json"])

        XCTAssertEqual(result.exitCode, 0, result.standardError)

        let data = Data(result.standardOutput.utf8)
        let parsed = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any],
            "output was not a JSON object: \(result.standardOutput)"
        )

        let scanStats = try XCTUnwrap(parsed["scanStats"] as? [String: Any])
        XCTAssertEqual(scanStats["scannedFiles"] as? Int, 2)

        let objects = try XCTUnwrap(parsed["objects"] as? [String: Any])
        XCTAssertEqual(objects["classes"] as? Int, 1)
        XCTAssertEqual(objects["structs"] as? Int, 1)
        XCTAssertEqual(objects["enums"] as? Int, 1)
        XCTAssertEqual(objects["protocols"] as? Int, 1)
    }

    /// `--path` pointing at a file rather than a directory is a separate branch
    /// of the walk, and one the library tests do not reach through the CLI.
    func testScanningASingleFile() throws {
        let fixture = try makeFixture()
        let result = try runSitrep(["--path", fixture.appendingPathComponent("top.swift").path])

        XCTAssertEqual(result.exitCode, 0, result.standardError)
        XCTAssertTrue(result.standardOutput.contains("Files scanned: 1"), result.standardOutput)
        XCTAssertTrue(result.standardOutput.contains("Classes: 1"), result.standardOutput)
        XCTAssertTrue(result.standardOutput.contains("Structs: 0"), result.standardOutput)
    }

    // MARK: - Configuration

    /// Exercises the whole configuration path end to end: the implicit
    /// `.sitrep.yml` lookup, Yams decoding it, and exclusions being applied to
    /// the walk.
    func testExcludedDirectoryIsSkipped() throws {
        let fixture = try makeFixture()
        try "excluded:\n  - nested\n"
            .write(to: fixture.appendingPathComponent(".sitrep.yml"), atomically: true, encoding: .utf8)

        let result = try runSitrep(["--path", fixture.path])

        XCTAssertEqual(result.exitCode, 0, result.standardError)
        // nested/deep.swift is gone, so only top.swift and its class remain.
        XCTAssertTrue(result.standardOutput.contains("Files scanned: 1"), result.standardOutput)
        XCTAssertTrue(result.standardOutput.contains("Classes: 1"), result.standardOutput)
        XCTAssertTrue(result.standardOutput.contains("Structs: 0"), result.standardOutput)
        XCTAssertTrue(result.standardOutput.contains("Enums: 0"), result.standardOutput)
    }

    func testInfoFlagReportsConfigurationWithoutScanning() throws {
        let fixture = try makeFixture()
        let result = try runSitrep(["--path", fixture.path, "--info"])

        XCTAssertEqual(result.exitCode, 0, result.standardError)
        XCTAssertTrue(result.standardOutput.contains("Configuration file:"), result.standardOutput)
        XCTAssertTrue(result.standardOutput.contains("Scan path: \(fixture.path)"), result.standardOutput)
        // -i prints configuration and exits; it must not also produce a report.
        XCTAssertFalse(result.standardOutput.contains("Files scanned:"), result.standardOutput)
    }

    // MARK: - Argument handling

    /// The binary must report exactly what Version.swift declares.
    ///
    /// This also pins the line's format. `mise run release` finds and rewrites
    /// `let sitrepVersion = "…"` textually, so if that line is ever reformatted
    /// this test fails here, rather than the release task failing mid-release.
    func testVersionFlagReportsVersionSwift() throws {
        let versionFile = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // SitrepTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root
            .appendingPathComponent("Sources/Sitrep/Version.swift")
        let source = try String(contentsOf: versionFile, encoding: .utf8)

        let prefix = "let sitrepVersion = \""
        let line = try XCTUnwrap(
            source.split(separator: "\n").first { $0.hasPrefix(prefix) && $0.hasSuffix("\"") },
            "Version.swift has no `\(prefix)…\"` line for mise run release to rewrite"
        )
        let declared = line.dropFirst(prefix.count).dropLast()

        let result = try runSitrep(["--version"])

        XCTAssertEqual(result.exitCode, 0, result.standardError)
        XCTAssertEqual(result.standardOutput.trimmingCharacters(in: .newlines), String(declared))
    }

    func testUnknownFormatIsRejected() throws {
        let fixture = try makeFixture()
        let result = try runSitrep(["--path", fixture.path, "--format", "yaml"])

        XCTAssertNotEqual(result.exitCode, 0, "an unknown format should not succeed")
        XCTAssertFalse(result.standardError.isEmpty, "a rejected argument should explain itself")
    }

    func testHelpListsTheCommandName() throws {
        let result = try runSitrep(["--help"])

        XCTAssertEqual(result.exitCode, 0, result.standardError)
        // Guards the CommandConfiguration: without it ArgumentParser derives the
        // name from the type, which would silently drift from the binary's name.
        XCTAssertTrue(result.standardOutput.contains("USAGE: sitrep"), result.standardOutput)
    }
}
