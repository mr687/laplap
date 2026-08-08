import XCTest
@testable import laplap

final class ArgParserTests: XCTestCase {
    func testParseAcceptsCat() throws {
        XCTAssertEqual(try ArgParser.parse(["laplap", "cat"]).get(), .cat)
    }

    func testParseAcceptsClean() throws {
        XCTAssertEqual(try ArgParser.parse(["laplap", "clean"]).get(), .clean)
    }

    func testParseAcceptsHelp() throws {
        XCTAssertEqual(try ArgParser.parse(["laplap", "--help"]).get(), .help)
    }

    func testParseUnknownModeFails() {
        let result = ArgParser.parse(["laplap", "bogus"])
        guard case .failure(let error) = result else {
            return XCTFail("expected failure, got \(result)")
        }
        XCTAssertEqual(error.argument, "bogus")
    }

    func testParseNoArgumentsFails() {
        let result = ArgParser.parse(["laplap"])
        guard case .failure = result else {
            return XCTFail("expected failure, got \(result)")
        }
    }

    func testUsageContainsModes() {
        XCTAssertTrue(ArgParser.usage.contains("cat"))
        XCTAssertTrue(ArgParser.usage.contains("clean"))
    }
}

/// Spawns the real built binary to verify exit codes and stderr routing.
/// Headless-safe: unknown-mode and --help paths never touch AppKit or HID.
final class ArgParserProcessTests: XCTestCase {
    private func laplapBinary() throws -> URL {
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent().appendingPathComponent("laplap")
        }
        throw XCTSkip("no xctest bundle found; cannot locate built binary")
    }

    private func run(_ arguments: [String]) throws -> (status: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = try laplapBinary()
        process.arguments = arguments
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        process.waitUntilExit()
        let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (process.terminationStatus, stdout, stderr)
    }

    func testUnknownModePrintsUsageToStderrAndExitsTwo() throws {
        let (status, _, stderr) = try run(["bogus"])
        XCTAssertEqual(status, 2)
        XCTAssertTrue(stderr.contains("Usage:"), "stderr was: \(stderr)")
    }

    func testHelpExitsZeroWithUsage() throws {
        let (status, stdout, _) = try run(["--help"])
        XCTAssertEqual(status, 0)
        XCTAssertTrue(stdout.contains("Usage:"), "stdout was: \(stdout)")
    }
}
