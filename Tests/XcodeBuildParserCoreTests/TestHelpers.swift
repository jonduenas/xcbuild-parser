import Foundation

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

enum TestError: Error {
    case fixtureNotFound(String)
}

// Placeholder class for Bundle resolution in non-SPM builds
private class _BundleReference {}
