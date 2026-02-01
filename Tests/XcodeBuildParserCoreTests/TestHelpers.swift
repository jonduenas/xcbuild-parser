import Foundation
import XcodeBuildParserCore

extension DateProvider {
    /// Mock date provider that returns a fixed date for deterministic testing
    static func mock(startDate: Date = Date(timeIntervalSince1970: 1000.0)) -> DateProvider {
        DateProvider(now: { startDate })
    }

    /// Mock date provider that increments by a fixed interval on each call
    static func incrementing(
        startDate: Date = Date(timeIntervalSince1970: 1000.0),
        interval: TimeInterval = 5.0
    ) -> DateProvider {
        var callCount = 0
        return DateProvider(now: {
            defer { callCount += 1 }
            return startDate.addingTimeInterval(Double(callCount) * interval)
        })
    }
}

/// Loads the contents of a test fixture file.
///
/// - Parameter name: The name of the fixture file (without path, e.g., "build-success.txt")
/// - Returns: An array of lines from the fixture file
/// - Throws: If the fixture file cannot be loaded
func loadFixture(_ name: String) throws -> [String] {
    #if SWIFT_PACKAGE
    let fixturesURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent(name)
    #else
    // Fallback for non-SPM builds
    let bundle = Bundle(for: _BundleReference.self)
    guard let fixturesURL = bundle.url(forResource: name, withExtension: nil) else {
        throw TestError.fixtureNotFound(name)
    }
    #endif

    let contents = try String(contentsOf: fixturesURL, encoding: .utf8)
    return contents.components(separatedBy: .newlines)
}

/// Returns a copy of the summary with buildTime set to "0.000" for snapshot consistency.
///
/// Alternative: Use DateProvider.mock() or DateProvider.incrementing() for actual buildTime testing.
func normalizedBuildTime(_ summary: BuildSummary) -> BuildSummary {
    BuildSummary(
        status: summary.status,
        summary: Summary(
            errors: summary.summary.errors,
            warnings: summary.summary.warnings,
            passedTests: summary.summary.passedTests,
            failedTests: summary.summary.failedTests,
            buildTime: "0.000"
        ),
        errors: summary.errors,
        warnings: summary.warnings,
        testResults: summary.testResults,
        xcresultPath: summary.xcresultPath
    )
}

enum TestError: Error {
    case fixtureNotFound(String)
}

// Placeholder class for Bundle resolution in non-SPM builds
private class _BundleReference {}
